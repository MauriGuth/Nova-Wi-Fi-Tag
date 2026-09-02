import Foundation

/// Tipo de seguridad de la red. El valor crudo es el que viaja en
/// `/api/tags/<tagId>.json` y el que se guarda en el Keychain.
enum WifiSecurity: String, Codable, CaseIterable, Identifiable, Hashable {
    /// WPA2-Personal (AES). Es lo más común.
    case wpa2 = "WPA2"
    /// Red en modo de transición WPA2/WPA3-Personal.
    case wpa2wpa3 = "WPA2-WPA3"
    /// Red mixta WPA/WPA2-Personal (routers viejos).
    case wpaWpa2 = "WPA-WPA2"
    /// Red abierta, sin clave.
    case open = "OPEN"

    var id: String { rawValue }

    /// Nombre para mostrar en pantalla.
    var displayName: String {
        switch self {
        case .wpa2: return "WPA2"
        case .wpa2wpa3: return "WPA2/WPA3"
        case .wpaWpa2: return "WPA/WPA2 (mixta)"
        case .open: return "Abierta (sin clave)"
        }
    }

    var requiresPassword: Bool { self != .open }

    /// Interpreta variantes habituales ("wpa2", "WPA2-Personal", "WPA3", "none"...).
    init(parsing raw: String) {
        let key = raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        switch key {
        case "", "OPEN", "NONE", "ABIERTA", "NOPASS":
            self = .open
        case "WPA2-WPA3", "WPA3", "WPA3-PERSONAL", "WPA2-WPA3-PERSONAL", "SAE", "WPA3-SAE":
            self = .wpa2wpa3
        case "WPA-WPA2", "WPA", "WPA-PERSONAL", "WPA-WPA2-PERSONAL", "WPA-PSK", "WPA-WPA2-PSK":
            self = .wpaWpa2
        default:
            self = .wpa2
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self.init(parsing: raw)
    }
}

/// Credenciales de una red asociadas a un sticker (`tagId`).
struct TagCredentials: Codable, Identifiable, Hashable {
    /// Identificador del sticker: el `<tagId>` de `https://wifi.novasolutions.ar/t/<tagId>`.
    var id: String
    /// Nombre amigable ("Wi-Fi de Mauri").
    var name: String
    var ssid: String
    var password: String
    var security: WifiSecurity

    init(id: String, name: String, ssid: String, password: String = "", security: WifiSecurity = .wpa2) {
        self.id = id
        self.name = name
        self.ssid = ssid
        self.password = password
        self.security = security
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, ssid, password, security
    }

    /// Decodificación tolerante: `name`, `password` y `security` son opcionales en el JSON.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let ssid = try container.decode(String.self, forKey: .ssid)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.ssid = ssid
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ssid
        self.password = try container.decodeIfPresent(String.self, forKey: .password) ?? ""
        self.security = try container.decodeIfPresent(WifiSecurity.self, forKey: .security) ?? .wpa2
    }

    /// URL que se graba en el sticker y que abre el App Clip.
    var tagURL: URL { NovaConfig.tagURL(for: id) }

    /// Un tagId válido tiene 1–64 caracteres ASCII: letras, números, guion y guion bajo.
    static func isValidTagId(_ id: String) -> Bool {
        let length = id.utf8.count
        guard length >= 1, length <= 64 else { return false }
        return id.utf8.allSatisfy { byte in
            (byte >= 0x30 && byte <= 0x39)      // 0-9
                || (byte >= 0x41 && byte <= 0x5A)  // A-Z
                || (byte >= 0x61 && byte <= 0x7A)  // a-z
                || byte == 0x2D                    // -
                || byte == 0x5F                    // _
        }
    }
}
