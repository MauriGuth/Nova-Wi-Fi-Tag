import Foundation

/// Constantes del servicio web que respalda los stickers.
enum NovaConfig {
    /// Dominio asociado (applinks / appclips).
    static let host = "wifi.novasolutions.ar"

    static let baseURL = URL(string: "https://\(host)")!

    /// URL que se graba en el sticker y que abre el App Clip:
    /// `https://wifi.novasolutions.ar/t/<tagId>`
    static func tagURL(for tagId: String) -> URL {
        baseURL.appendingPathComponent("t").appendingPathComponent(tagId)
    }

    /// Endpoint con las credenciales de la red:
    /// `https://wifi.novasolutions.ar/api/tags/<tagId>.json`
    static func apiURL(for tagId: String) -> URL {
        baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("tags")
            .appendingPathComponent("\(tagId).json")
    }
}
