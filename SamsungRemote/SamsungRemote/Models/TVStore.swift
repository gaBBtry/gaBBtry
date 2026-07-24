import Foundation

/// Persiste la liste des TV connues et le jeton d'appairage de chacune.
@MainActor
final class TVStore: ObservableObject {

    @Published private(set) var devices: [TVDevice] = []
    @Published private(set) var selectedID: String? {
        didSet { defaults.set(selectedID, forKey: Keys.selected) }
    }

    private enum Keys {
        static let devices = "tv.devices"
        static let selected = "tv.selectedID"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var selectedDevice: TVDevice? {
        devices.first { $0.id == selectedID }
    }

    /// Ajoute la TV (ou met à jour ses infos si elle est déjà connue) et la sélectionne.
    func select(_ device: TVDevice) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            var known = devices[index]
            known.name = device.name
            known.host = device.host
            known.modelName = device.modelName ?? known.modelName
            known.macAddress = device.macAddress ?? known.macAddress
            devices[index] = known
        } else {
            devices.append(device)
        }
        selectedID = device.id
        persist()
    }

    func updateToken(_ token: String, for id: String) {
        guard let index = devices.firstIndex(where: { $0.id == id }),
              devices[index].token != token else { return }
        devices[index].token = token
        persist()
    }

    /// Oublie l'appairage : la TV redemandera une autorisation à la prochaine connexion.
    func forgetToken(for id: String) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        devices[index].token = nil
        persist()
    }

    func remove(_ device: TVDevice) {
        devices.removeAll { $0.id == device.id }
        if selectedID == device.id {
            selectedID = devices.first?.id
        }
        persist()
    }

    // MARK: - Stockage

    private func load() {
        if let data = defaults.data(forKey: Keys.devices),
           let decoded = try? JSONDecoder().decode([TVDevice].self, from: data) {
            devices = decoded
        }
        selectedID = defaults.string(forKey: Keys.selected)
        if selectedDevice == nil {
            selectedID = devices.first?.id
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: Keys.devices)
        }
        defaults.set(selectedID, forKey: Keys.selected)
    }
}
