// Agentboard/Core/WebSocketClient.swift
import Foundation

@Observable
class WebSocketClient {
    // MARK: - Singleton
    static let shared = WebSocketClient()

    // MARK: - State
    private(set) var isConnected = false
    private var webSocket: URLSessionWebSocketTask?
    private var serverURL: URL?
    private var reconnectAttempt = 0
    private let maxReconnectDelay: TimeInterval = 30

    // MARK: - Callbacks
    var onMessage: ((ServerMessage) -> Void)?
    var onConnectionChange: ((ConnectionStatus) -> Void)?

    // MARK: - JSON Coding
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Connection

    func connect(to url: URL) {
        disconnect()

        serverURL = url

        // Convert http(s) URL to ws(s) URL
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.scheme = url.scheme == "https" ? "wss" : "ws"
        components.path = (components.path.isEmpty ? "" : components.path) + "/ws"

        guard let wsURL = components.url else {
            onConnectionChange?(.error("Invalid WebSocket URL"))
            return
        }

        onConnectionChange?(.connecting)

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: wsURL)
        webSocket?.resume()

        isConnected = true
        reconnectAttempt = 0
        onConnectionChange?(.connected)

        receiveMessage()
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
        onConnectionChange?(.disconnected)
    }

    // MARK: - Sending

    func send(_ message: ClientMessage) {
        guard let webSocket, isConnected else {
            print("[WS] Cannot send - not connected")
            return
        }

        do {
            let data = try encoder.encode(message)
            webSocket.send(.data(data)) { error in
                if let error {
                    print("[WS] Send error: \(error)")
                }
            }
        } catch {
            print("[WS] Encode error: \(error)")
        }
    }

    // MARK: - Receiving

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveMessage() // Continue listening

            case .failure(let error):
                print("[WS] Receive error: \(error)")
                self.isConnected = false
                self.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data

        switch message {
        case .data(let d):
            data = d
        case .string(let s):
            data = Data(s.utf8)
        @unknown default:
            return
        }

        do {
            let serverMessage = try decoder.decode(ServerMessage.self, from: data)
            DispatchQueue.main.async {
                self.onMessage?(serverMessage)
            }
        } catch {
            print("[WS] Decode error: \(error)")
            if let str = String(data: data, encoding: .utf8) {
                print("[WS] Raw message: \(str.prefix(200))")
            }
        }
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        guard let serverURL else { return }

        reconnectAttempt += 1
        let delay = min(pow(2, Double(reconnectAttempt)), maxReconnectDelay)

        onConnectionChange?(.reconnecting(attempt: reconnectAttempt))

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect(to: serverURL)
        }
    }
}
