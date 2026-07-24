import Foundation

/// Raccourci vers une application Tizen installée sur la TV.
struct TVApp: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    var actionType: String = "DEEP_LINK"

    /// Identifiants d'apps communs aux TV Samsung récentes.
    /// Si une app n'est pas installée sur la TV, la commande est simplement ignorée.
    static let shortcuts: [TVApp] = [
        TVApp(id: "3201907018807", name: "Netflix", symbol: "film"),
        TVApp(id: "111299001912", name: "YouTube", symbol: "play.rectangle"),
        TVApp(id: "3201910019365", name: "Prime Video", symbol: "popcorn"),
        TVApp(id: "3201901017640", name: "Disney+", symbol: "sparkles.tv"),
        TVApp(id: "3201606009684", name: "Spotify", symbol: "music.note"),
        TVApp(id: "3202203026841", name: "Molotov", symbol: "antenna.radiowaves.left.and.right")
    ]
}
