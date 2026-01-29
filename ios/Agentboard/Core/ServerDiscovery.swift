// Agentboard/Core/ServerDiscovery.swift
import Foundation
import Network

@Observable
class ServerDiscovery {
    private var browser: NWBrowser?
    private(set) var discoveredServers: [DiscoveredServer] = []
    private(set) var isSearching = false

    struct DiscoveredServer: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let endpoint: NWEndpoint
        var resolvedURL: URL?
    }

    func startDiscovery() {
        stopDiscovery()

        let params = NWParameters()
        params.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: "_agentboard._tcp", domain: nil), using: params)

        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isSearching = true
                case .failed, .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                self?.discoveredServers = results.compactMap { result in
                    guard case .service(let name, _, _, _) = result.endpoint else {
                        return nil
                    }
                    return DiscoveredServer(name: name, endpoint: result.endpoint)
                }
            }
        }

        browser?.start(queue: .main)
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    func resolve(_ server: DiscoveredServer, completion: @escaping (URL?) -> Void) {
        let params = NWParameters.tcp
        let connection = NWConnection(to: server.endpoint, using: params)

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = innerEndpoint {
                    let urlString = "http://\(host):\(port)"
                    let url = URL(string: urlString)
                    DispatchQueue.main.async {
                        completion(url)
                    }
                }
                connection.cancel()
            }
        }

        connection.start(queue: .global())

        // Timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            if connection.state != .ready {
                connection.cancel()
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
