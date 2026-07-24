import Foundation

/// Client du canal WebSocket `samsung.remote.control` exposé par les TV Samsung Tizen.
///
/// Déroulé de l'appairage :
/// 1. l'app ouvre `wss://<ip>:8002/api/v2/channels/samsung.remote.control?name=<nom base64>` ;
/// 2. la TV affiche une demande d'autorisation ;
/// 3. une fois acceptée, elle renvoie `ms.channel.connect` avec un jeton ;
/// 4. le jeton est conservé et rejoué (`&token=…`) pour éviter la demande suivante.
@MainActor
final class SamsungTVClient: NSObject, ObservableObject {

    enum ConnectionState: Equatable {
        case idle
        case connecting
        /// La TV affiche la demande d'autorisation, en attente de l'accord de l'utilisateur.
        case awaitingAuthorization
        case connected
        case failed(String)

        var canSendCommands: Bool { self == .connected }
    }

    @Published private(set) var state: ConnectionState = .idle

    /// Appelé quand la TV délivre un jeton d'appairage, à persister côté app.
    var onTokenReceived: (@MainActor (String) -> Void)?

    private static let clientName = "iPhone"
    private static let keepAliveInterval: UInt64 = 20 * NSEC_PER_SEC

    private var session: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var keepAliveTask: Task<Void, Never>?
    private var device: TVDevice?

    // MARK: - Connexion

    func connect(to device: TVDevice) {
        if self.device == device, state == .connected || state == .connecting { return }
        disconnect()
        self.device = device

        guard let url = Self.controlURL(host: device.host, token: device.token) else {
            state = .failed("Adresse de la TV invalide")
            return
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session

        let socket = session.webSocketTask(with: url)
        self.socket = socket
        state = device.isPaired ? .connecting : .awaitingAuthorization
        socket.resume()

        listen(on: socket)
        startKeepAlive()
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        keepAliveTask?.cancel()
        keepAliveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        session?.invalidateAndCancel()
        session = nil
        state = .idle
    }

    func reconnect() {
        guard let device else { return }
        disconnect()
        connect(to: device)
    }

    // MARK: - Commandes

    /// Appui bref sur une touche.
    func send(_ key: RemoteKey) {
        sendRemoteKey(command: "Click", key: key)
    }

    /// Début d'un appui long (à terminer par `release(_:)`).
    func press(_ key: RemoteKey) {
        sendRemoteKey(command: "Press", key: key)
    }

    func release(_ key: RemoteKey) {
        sendRemoteKey(command: "Release", key: key)
    }

    /// Saisit du texte dans le champ actuellement actif sur la TV.
    func sendText(_ text: String) {
        guard !text.isEmpty else { return }
        send(payload: [
            "method": "ms.remote.control",
            "params": [
                "Cmd": Data(text.utf8).base64EncodedString(),
                "DataOfCmd": "base64",
                "TypeOfRemote": "SendInputString"
            ]
        ])
    }

    func launch(_ app: TVApp) {
        send(payload: [
            "method": "ms.channel.emit",
            "params": [
                "event": "ed.apps.launch",
                "to": "host",
                "data": ["appId": app.id, "action_type": app.actionType]
            ]
        ])
    }

    /// Réveille la TV éteinte via un paquet magique Wake-on-LAN.
    func wakeUp() {
        guard let device, let mac = device.macAddress else { return }
        WakeOnLAN.send(mac: mac, to: device.host)
    }

    private func sendRemoteKey(command: String, key: RemoteKey) {
        send(payload: [
            "method": "ms.remote.control",
            "params": [
                "Cmd": command,
                "DataOfCmd": key.rawValue,
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey"
            ]
        ])
    }

    private func send(payload: [String: Any]) {
        guard state.canSendCommands, let socket,
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }

        socket.send(.string(text)) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.fail(with: error) }
        }
    }

    // MARK: - Réception

    private func listen(on socket: URLSessionWebSocketTask) {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await socket.receive()
                    guard !Task.isCancelled else { return }
                    self?.handle(message)
                } catch {
                    guard !Task.isCancelled else { return }
                    self?.fail(with: error)
                    return
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case let .string(text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }

        switch event {
        case "ms.channel.connect":
            state = .connected
            if let payload = json["data"] as? [String: Any],
               let token = payload["token"] as? String, !token.isEmpty {
                device?.token = token
                onTokenReceived?(token)
            }
        case "ms.channel.unauthorized":
            state = .failed("Autorisation refusée sur la TV")
        case "ms.channel.timeOut":
            state = .failed("La TV n'a pas répondu à la demande d'autorisation")
        default:
            break
        }
    }

    private func fail(with error: Error) {
        keepAliveTask?.cancel()
        keepAliveTask = nil

        let code = (error as NSError).code
        switch code {
        case NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost:
            state = .failed("TV injoignable — vérifie qu'elle est allumée et sur le même Wi-Fi")
        case NSURLErrorNotConnectedToInternet:
            state = .failed("iPhone hors réseau Wi-Fi")
        default:
            state = .failed(error.localizedDescription)
        }
    }

    /// Les TV coupent le canal après quelques dizaines de secondes d'inactivité.
    private func startKeepAlive() {
        keepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.keepAliveInterval)
                guard !Task.isCancelled, let socket = self?.socket else { return }
                socket.sendPing { _ in }
            }
        }
    }

    private static func controlURL(host: String, token: String?) -> URL? {
        guard !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "wss"
        components.host = host
        components.port = 8002
        components.path = "/api/v2/channels/samsung.remote.control"

        var items = [URLQueryItem(name: "name", value: Data(clientName.utf8).base64EncodedString())]
        if let token, !token.isEmpty {
            items.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = items
        return components.url
    }
}

extension SamsungTVClient: URLSessionDelegate {
    /// Le port 8002 des TV Samsung présente un certificat auto-signé : on accepte
    /// explicitement la confiance serveur pour cet hôte du réseau local.
    nonisolated func urlSession(_ session: URLSession,
                                didReceive challenge: URLAuthenticationChallenge,
                                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
