import Foundation

/// Construye el payload "Wi-Fi Simple Configuration" (WSC) que Android
/// interpreta en un registro NDEF MIME `application/vnd.wfa.wsc`.
///
/// Formato: TLVs big-endian (tipo 2 bytes, longitud 2 bytes, valor).
/// Un atributo Credential (0x100E) contiene:
///   Network Index 0x1026 (1 byte = 1), SSID 0x1045, Auth Type 0x1003 (2 bytes),
///   Encryption Type 0x100F (2 bytes), Network Key 0x1027 y MAC Address 0x1020 (6 × 0xFF).
enum WSCPayload {
    static let mimeType = "application/vnd.wfa.wsc"

    enum Attribute: UInt16 {
        case authType = 0x1003
        case credential = 0x100E
        case encryptionType = 0x100F
        case macAddress = 0x1020
        case networkIndex = 0x1026
        case networkKey = 0x1027
        case ssid = 0x1045
    }

    enum AuthType: UInt16 {
        case open = 0x0001
        case wpaPersonal = 0x0002
        case wpa2Personal = 0x0020
        /// WPA-Personal | WPA2-Personal (red mixta).
        case wpaWpa2Personal = 0x0022
    }

    enum EncryptionType: UInt16 {
        case noEncryption = 0x0001
        case tkip = 0x0004
        case aes = 0x0008
        /// TKIP | AES.
        case tkipAes = 0x000C
    }

    /// WSC no define WPA3: una red WPA2/WPA3 (modo transición) se anuncia como WPA2-Personal,
    /// que Android une con PSK sin problema.
    static func authType(for security: WifiSecurity) -> AuthType {
        switch security {
        case .wpa2, .wpa2wpa3: return .wpa2Personal
        case .wpaWpa2: return .wpaWpa2Personal
        case .open: return .open
        }
    }

    static func encryptionType(for security: WifiSecurity) -> EncryptionType {
        switch security {
        case .wpa2, .wpa2wpa3: return .aes
        case .wpaWpa2: return .tkipAes
        case .open: return .noEncryption
        }
    }

    static func build(for credentials: TagCredentials) -> Data {
        var credential = Data()
        credential.appendWSC(.networkIndex, Data([0x01]))
        credential.appendWSC(.ssid, Data(credentials.ssid.utf8))
        credential.appendWSC(.authType, authType(for: credentials.security).rawValue.bigEndianBytes)
        credential.appendWSC(.encryptionType, encryptionType(for: credentials.security).rawValue.bigEndianBytes)
        credential.appendWSC(.networkKey, Data(credentials.password.utf8))
        credential.appendWSC(.macAddress, Data(repeating: 0xFF, count: 6))

        var payload = Data()
        payload.appendWSC(.credential, credential)
        return payload
    }
}

private extension Data {
    mutating func appendWSC(_ attribute: WSCPayload.Attribute, _ value: Data) {
        append(attribute.rawValue.bigEndianBytes)
        append(UInt16(value.count).bigEndianBytes)
        append(value)
    }
}

private extension UInt16 {
    var bigEndianBytes: Data {
        Data([UInt8(self >> 8), UInt8(self & 0x00FF)])
    }
}
