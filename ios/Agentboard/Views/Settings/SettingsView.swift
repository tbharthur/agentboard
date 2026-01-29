// Agentboard/Views/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) var appState

    @AppStorage("serverURL") private var serverURL = "http://m4mini.local:4040"
    @AppStorage("autoDiscovery") private var autoDiscovery = true
    @AppStorage("terminalFontSize") private var fontSize = 14.0
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("scanlineEffect") private var scanlineEffect = false

    @State private var discovery = ServerDiscovery()

    var body: some View {
        NavigationStack {
            Form {
                // Server section
                Section {
                    Toggle("Auto-discover", isOn: $autoDiscovery)
                        .onChange(of: autoDiscovery) { _, enabled in
                            if enabled {
                                discovery.startDiscovery()
                            } else {
                                discovery.stopDiscovery()
                            }
                        }

                    if autoDiscovery {
                        if discovery.isSearching {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Searching...")
                                    .font(Fonts.dmMono(12))
                                    .foregroundColor(.textMuted)
                            }
                        }

                        ForEach(discovery.discoveredServers) { server in
                            Button(action: {
                                discovery.resolve(server) { url in
                                    if let url {
                                        serverURL = url.absoluteString
                                        WebSocketClient.shared.connect(to: url)
                                    }
                                }
                            }) {
                                HStack {
                                    Text(server.name)
                                        .font(Fonts.dmMono(14))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.textMuted)
                                }
                            }
                        }
                    } else {
                        TextField("Server URL", text: $serverURL)
                            .font(Fonts.dmMono(14))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button("Connect") {
                            if let url = URL(string: serverURL) {
                                WebSocketClient.shared.connect(to: url)
                            }
                        }
                        .font(Fonts.dmMonoMedium(12))
                    }

                    // Connection status
                    HStack {
                        Text("Status")
                            .font(Fonts.dmMono(12))
                        Spacer()
                        Text(appState.connectionStatus.displayText)
                            .font(Fonts.dmMono(12))
                            .foregroundColor(appState.connectionStatus.color)
                    }
                } header: {
                    Text("SERVER")
                        .font(Fonts.dmMonoMedium(11))
                }

                // Terminal section
                Section {
                    HStack {
                        Text("Font size")
                            .font(Fonts.dmMono(14))
                        Spacer()
                        Text("\(Int(fontSize))pt")
                            .font(Fonts.dmMono(12))
                            .foregroundColor(.textMuted)
                    }

                    Slider(value: $fontSize, in: 10...24, step: 1)
                        .tint(.accent)

                    Toggle("Scanline effect", isOn: $scanlineEffect)
                } header: {
                    Text("TERMINAL")
                        .font(Fonts.dmMonoMedium(11))
                }

                // Controls section
                Section {
                    Toggle("Haptic feedback", isOn: $hapticFeedback)
                        .onChange(of: hapticFeedback) { _, enabled in
                            HapticEngine.shared.setEnabled(enabled)
                        }
                } header: {
                    Text("CONTROLS")
                        .font(Fonts.dmMonoMedium(11))
                }

                // About section
                Section {
                    HStack {
                        Text("Version")
                            .font(Fonts.dmMono(14))
                        Spacer()
                        Text("1.0.0")
                            .font(Fonts.dmMono(12))
                            .foregroundColor(.textMuted)
                    }
                } header: {
                    Text("ABOUT")
                        .font(Fonts.dmMonoMedium(11))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(Fonts.dmMonoMedium(14))
                }
            }
            .toolbarBackground(Color.bgElevated, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            if autoDiscovery {
                discovery.startDiscovery()
            }
        }
        .onDisappear {
            discovery.stopDiscovery()
        }
    }
}
