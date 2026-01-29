// Agentboard/Views/RootView.swift
import SwiftUI

struct RootView: View {
    @State private var appState = AppState.shared
    @State private var terminalManager = TerminalManager()
    @State private var showingDrawer = false
    @State private var dragOffset: CGFloat = 0

    // Control mode components
    @State private var contentModel = SessionContentModel()
    @State private var outputBuffer: OutputBuffer?
    @State private var flowController: FlowController?
    @State private var useControlMode = false

    private let drawerWidth = UIScreen.main.bounds.width * 0.75

    var body: some View {
        ZStack(alignment: .leading) {
            // Main terminal view
            MainTerminalView(useControlMode: useControlMode, contentModel: contentModel)
                .environment(appState)
                .environment(terminalManager)
                .offset(x: showingDrawer ? drawerWidth : 0)
                .animation(.easeOut(duration: 0.15), value: showingDrawer)

            // Drawer overlay (dims main content)
            if showingDrawer {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .offset(x: drawerWidth)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showingDrawer = false
                        }
                    }
            }

            // Session drawer
            SessionDrawer(
                onKillSession: { sessionId in
                    WebSocketClient.shared.send(.sessionKill(sessionId: sessionId))
                },
                onNewSession: {
                    // TODO: Show new session modal
                }
            )
            .environment(appState)
            .offset(x: showingDrawer ? 0 : -drawerWidth)
            .animation(.easeOut(duration: 0.15), value: showingDrawer)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    handleDrag(value)
                }
                .onEnded { value in
                    handleDragEnd(value)
                }
        )
        .onAppear {
            setupWebSocket()
        }
        .onChange(of: appState.activeSessionId) { oldId, newId in
            // Update terminal manager's active session
            terminalManager.setActiveSession(newId)

            // Reset control mode state on session switch
            contentModel.clear()
            outputBuffer?.stop()
            flowController?.reset()
            useControlMode = false

            // Detach from old session
            if let oldId {
                WebSocketClient.shared.send(.terminalDetach(sessionId: oldId))
            }
            // Attach to new session
            if let newId {
                attachToSession(newId)
            }
        }
        .sheet(isPresented: $appState.showingSettings) {
            SettingsView()
                .environment(appState)
        }
    }

    private func attachToSession(_ sessionId: String) {
        let dims = terminalManager.bestDimensions
        WebSocketClient.shared.send(.terminalAttach(sessionId: sessionId, cols: dims.cols, rows: dims.rows))
    }

    // MARK: - Gesture Handling

    private func handleDrag(_ value: DragGesture.Value) {
        let startX = value.startLocation.x
        let translation = value.translation.width

        // Open drawer: start from left edge, drag right
        if !showingDrawer && startX < 30 && translation > 0 {
            dragOffset = min(translation, drawerWidth)
        }

        // Close drawer: start anywhere, drag left
        if showingDrawer && translation < 0 {
            dragOffset = max(translation, -drawerWidth)
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        let velocity = value.predictedEndTranslation.width - value.translation.width
        let threshold = drawerWidth * 0.3

        withAnimation(.easeOut(duration: 0.15)) {
            if !showingDrawer {
                // Opening
                if dragOffset > threshold || velocity > 500 {
                    showingDrawer = true
                }
            } else {
                // Closing
                if -dragOffset > threshold || velocity < -500 {
                    showingDrawer = false
                }
            }
            dragOffset = 0
        }
    }

    // MARK: - WebSocket Setup

    private func setupWebSocket() {
        let client = WebSocketClient.shared

        // Initialize control mode components
        outputBuffer = OutputBuffer(fps: 60) { [contentModel] flushedData in
            contentModel.appendContent(flushedData)
        }
        flowController = FlowController { sessionId, paneId, action in
            WebSocketClient.shared.send(.terminalFlow(sessionId: sessionId, paneId: paneId, action: action))
        }

        client.onConnectionChange = { status in
            appState.connectionStatus = status
        }

        client.onMessage = { message in
            handleMessage(message)
        }

        // Connect to server
        // TODO: Use ServerDiscovery or saved URL
        if let url = URL(string: "http://m4mini.local:4040") {
            client.connect(to: url)
        }
    }

    private func handleMessage(_ message: ServerMessage) {
        switch message {
        case .sessions(let sessions):
            let hadNoSession = appState.activeSessionId == nil
            appState.updateSessions(sessions)
            // Attach to auto-selected session
            if hadNoSession, let sessionId = appState.activeSessionId {
                terminalManager.setActiveSession(sessionId)
                attachToSession(sessionId)
            }

        case .sessionUpdate(let session):
            appState.updateSession(session)

        case .sessionCreated(let session):
            appState.addSession(session)

        case .sessionRemoved(let sessionId):
            appState.removeSession(id: sessionId)

        case .agentSessions(let active, let inactive):
            appState.agentSessions = (active, inactive)

        case .terminalOutput(let sessionId, let data):
            // Only process output for the active session
            guard sessionId == appState.activeSessionId else { return }
            // Feed directly to terminal manager (bypasses SwiftUI)
            terminalManager.feed(sessionId: sessionId, data: data)

        // Control mode messages
        case .cmOutput(let sessionId, let paneId, let data, _):
            guard sessionId == appState.activeSessionId else { return }
            useControlMode = true
            outputBuffer?.append(data)
            flowController?.trackIncoming(sessionId: sessionId, paneId: paneId, byteCount: data.utf8.count)

        case .cmCommandStart(let sessionId, let cmdNum, _):
            print("[CM] Command \(cmdNum) started for \(sessionId)")

        case .cmCommandEnd(let sessionId, let cmdNum, let success):
            print("[CM] Command \(cmdNum) \(success ? "succeeded" : "failed") for \(sessionId)")

        case .cmWindow(let sessionId, let event, let windowId, let name):
            print("[CM] Window \(event): \(windowId) name=\(name ?? "nil") session=\(sessionId)")

        case .cmSession(let sessionId, let event, let name):
            print("[CM] Session \(event): \(name) id=\(sessionId)")

        case .cmFlow(let sessionId, let event, let paneId):
            print("[CM] Flow \(event) pane=\(paneId) session=\(sessionId)")

        case .cmExit(let sessionId, let reason):
            print("[CM] Exit session=\(sessionId) reason=\(reason ?? "none")")

        case .terminalReady(let sessionId):
            // Send resize (not re-attach) to correct dimensions without triggering
            // another full attach→capture→ready cycle
            if let size = terminalManager.getSize(sessionId: sessionId) {
                WebSocketClient.shared.send(
                    .terminalResize(sessionId: sessionId, cols: size.cols, rows: size.rows)
                )
            }

        case .terminalError(_, _, let message, _):
            print("[Terminal Error] \(message)")

        case .error(let message):
            print("[Server Error] \(message)")

        case .unknown(let type):
            print("[Unknown message type] \(type)")
        }
    }
}
