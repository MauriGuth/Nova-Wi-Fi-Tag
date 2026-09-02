import Foundation

/// Parseo de la URL de invocación del App Clip / enlace universal.
enum InvocationURL {
    /// Extrae el `tagId` de `https://wifi.novasolutions.ar/t/<tagId>`.
    /// Devuelve `nil` si la ruta no tiene esa forma o el id no es válido.
    static func tagId(from url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2, components[0] == "t" else { return nil }
        let candidate = components[1]
        return TagCredentials.isValidTagId(candidate) ? candidate : nil
    }
}
