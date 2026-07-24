import Foundation

/// Balaye le sous-réseau /24 de l'iPhone à la recherche de TV Samsung.
///
/// Chaque TV Tizen expose ses informations en HTTP sur `http://<ip>:8001/api/v2/`.
/// On interroge donc les 254 adresses du sous-réseau en unicast — pas de SSDP,
/// qui exigerait l'entitlement multicast d'Apple.
@MainActor
final class TVDiscovery: ObservableObject {

    @Published private(set) var devices: [TVDevice] = []
    @Published private(set) var isScanning = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var errorMessage: String?

    private static let maxConcurrentProbes = 24

    private var scanTask: Task<Void, Never>?

    func scan() {
        guard !isScanning else { return }
        guard let address = LocalNetwork.wifiAddress(),
              let prefix = LocalNetwork.subnetPrefix(from: address) else {
            errorMessage = "Réseau Wi-Fi introuvable. Connecte l'iPhone au même Wi-Fi que la TV."
            return
        }

        errorMessage = nil
        devices = []
        progress = 0
        isScanning = true

        let hosts = (1...254).map { "\(prefix).\($0)" }

        scanTask = Task {
            await withTaskGroup(of: TVDevice?.self) { group in
                var iterator = hosts.makeIterator()
                var inFlight = 0

                for _ in 0..<Self.maxConcurrentProbes {
                    guard let host = iterator.next() else { break }
                    group.addTask { await TVProbe.probe(host: host) }
                    inFlight += 1
                }

                var completed = 0
                while inFlight > 0, let result = await group.next() {
                    inFlight -= 1
                    completed += 1
                    progress = Double(completed) / Double(hosts.count)

                    if let device = result, !devices.contains(where: { $0.host == device.host }) {
                        devices.append(device)
                    }

                    if !Task.isCancelled, let host = iterator.next() {
                        group.addTask { await TVProbe.probe(host: host) }
                        inFlight += 1
                    }
                }
            }

            progress = 1
            isScanning = false
            if devices.isEmpty && !Task.isCancelled {
                errorMessage = "Aucune TV trouvée. Vérifie qu'elle est allumée, puis réessaie ou saisis son adresse IP."
            }
        }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    /// Interroge une adresse précise, saisie à la main par l'utilisateur.
    func lookUp(host: String) async -> TVDevice? {
        await TVProbe.probe(host: host, timeout: 4)
    }
}

/// Sonde HTTP sans isolation d'acteur, appelable depuis n'importe quelle tâche.
private enum TVProbe {

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 3
        configuration.waitsForConnectivity = false
        configuration.httpMaximumConnectionsPerHost = 2
        configuration.allowsCellularAccess = false
        return URLSession(configuration: configuration)
    }()

    static func probe(host: String, timeout: TimeInterval = 2) async -> TVDevice? {
        guard let url = URL(string: "http://\(host):8001/api/v2/") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let info = try? JSONDecoder().decode(DeviceInfo.self, from: data),
              let device = info.device else { return nil }

        return TVDevice(id: info.id ?? host,
                        name: device.name ?? info.name ?? "TV Samsung",
                        modelName: device.modelName,
                        host: host,
                        macAddress: device.wifiMac,
                        token: nil)
    }

    private struct DeviceInfo: Decodable {
        struct Device: Decodable {
            let name: String?
            let modelName: String?
            let wifiMac: String?
        }
        let id: String?
        let name: String?
        let device: Device?
    }
}
