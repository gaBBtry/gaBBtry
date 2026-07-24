import Foundation

/// Un téléviseur Samsung repéré sur le réseau local.
struct TVDevice: Identifiable, Codable, Hashable {
    /// Identifiant renvoyé par la TV (`uuid:...`), ou l'adresse IP en secours.
    var id: String
    var name: String
    var modelName: String?
    /// Adresse IPv4 sur le réseau local.
    var host: String
    /// Adresse MAC Wi-Fi, nécessaire pour l'allumage par Wake-on-LAN.
    var macAddress: String?
    /// Jeton d'appairage renvoyé par la TV après autorisation.
    var token: String?

    var displayName: String {
        name.isEmpty ? host : name
    }

    var subtitle: String {
        [modelName, host].compactMap { $0 }.joined(separator: " · ")
    }

    var isPaired: Bool {
        token?.isEmpty == false
    }
}
