import Foundation
import Darwin

/// Utilitaires pour situer l'iPhone sur son réseau Wi-Fi.
enum LocalNetwork {

    /// Adresse IPv4 de l'interface Wi-Fi (`en0`), ou `nil` si l'iPhone n'est pas en Wi-Fi.
    static func wifiAddress() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET),
                  String(cString: interface.ifa_name) == "en0" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(address,
                                     socklen_t(address.pointee.sa_len),
                                     &hostname,
                                     socklen_t(hostname.count),
                                     nil,
                                     0,
                                     NI_NUMERICHOST)
            if result == 0 {
                return String(cString: hostname)
            }
        }
        return nil
    }

    /// Préfixe /24 d'une adresse IPv4 : `192.168.1.42` → `192.168.1`.
    static func subnetPrefix(from address: String) -> String? {
        let parts = address.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return parts.dropLast().joined(separator: ".")
    }

    /// Vrai si la chaîne est une adresse IPv4 bien formée.
    static func isValidIPv4(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard !part.isEmpty, part.count <= 3, part.allSatisfy(\.isNumber),
                  let value = Int(part) else { return false }
            return (0...255).contains(value)
        }
    }
}
