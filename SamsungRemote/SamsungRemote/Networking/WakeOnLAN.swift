import Foundation
import Network

/// Envoi d'un paquet magique Wake-on-LAN pour rallumer une TV éteinte.
///
/// Le canal WebSocket n'existe plus quand la TV est éteinte : seul le Wake-on-LAN
/// permet de la rallumer, et uniquement si l'option « Mise sous tension par mobile »
/// (ou « Réseau en veille ») est activée dans les réglages de la TV.
enum WakeOnLAN {

    static func send(mac: String, to host: String) {
        guard let packet = magicPacket(mac: mac) else { return }

        // Unicast vers la dernière IP connue, plus l'adresse de diffusion du sous-réseau.
        // La diffusion nécessite l'entitlement multicast d'Apple ; sans lui, seul
        // l'envoi unicast aboutit — ce qui suffit tant que l'entrée ARP est fraîche.
        let targets = [host, broadcastAddress(for: host)].compactMap { $0 }
        for target in targets {
            transmit(packet, to: target)
        }
    }

    /// 6 octets à 0xFF suivis de 16 répétitions de l'adresse MAC.
    static func magicPacket(mac: String) -> Data? {
        let bytes = mac
            .split(whereSeparator: { $0 == ":" || $0 == "-" })
            .compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return nil }

        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: bytes)
        }
        return packet
    }

    private static func transmit(_ packet: Data, to target: String) {
        let connection = NWConnection(host: NWEndpoint.Host(target), port: 9, using: .udp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: packet, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .utility))
    }

    private static func broadcastAddress(for host: String) -> String? {
        var parts = host.split(separator: ".")
        guard parts.count == 4 else { return nil }
        parts[3] = "255"
        return parts.joined(separator: ".")
    }
}
