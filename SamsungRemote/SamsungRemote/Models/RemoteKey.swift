import Foundation

/// Codes touches du canal `samsung.remote.control` (TV Tizen, modèles 2016 et suivants).
enum RemoteKey: String {
    // Alimentation et sources
    case power = "KEY_POWER"
    case source = "KEY_SOURCE"
    case hdmi = "KEY_HDMI"

    // Navigation
    case up = "KEY_UP"
    case down = "KEY_DOWN"
    case left = "KEY_LEFT"
    case right = "KEY_RIGHT"
    case enter = "KEY_ENTER"
    case back = "KEY_RETURN"
    case exit = "KEY_EXIT"
    case home = "KEY_HOME"
    case menu = "KEY_MENU"
    case tools = "KEY_TOOLS"
    case guide = "KEY_GUIDE"
    case info = "KEY_INFO"

    // Volume
    case volumeUp = "KEY_VOLUP"
    case volumeDown = "KEY_VOLDOWN"
    case mute = "KEY_MUTE"

    // Chaînes
    case channelUp = "KEY_CHUP"
    case channelDown = "KEY_CHDOWN"
    case channelList = "KEY_CH_LIST"
    case previousChannel = "KEY_PRECH"

    // Lecture
    case play = "KEY_PLAY"
    case pause = "KEY_PAUSE"
    case playPause = "KEY_PLAY_BACK"
    case stop = "KEY_STOP"
    case rewind = "KEY_REWIND"
    case fastForward = "KEY_FF"

    // Pavé numérique
    case digit0 = "KEY_0"
    case digit1 = "KEY_1"
    case digit2 = "KEY_2"
    case digit3 = "KEY_3"
    case digit4 = "KEY_4"
    case digit5 = "KEY_5"
    case digit6 = "KEY_6"
    case digit7 = "KEY_7"
    case digit8 = "KEY_8"
    case digit9 = "KEY_9"

    /// Touche numérique correspondant à un chiffre de 0 à 9.
    static func digit(_ value: Int) -> RemoteKey? {
        RemoteKey(rawValue: "KEY_\(value)")
    }
}
