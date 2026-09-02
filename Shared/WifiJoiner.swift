import Foundation
import NetworkExtension

enum WifiJoinError: LocalizedError {
    case invalidSSID
    case invalidPassphrase
    case userDenied
    case notInForeground
    case pending
    case simulator
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSSID:
            return "El nombre de la red (SSID) no es válido: debe tener entre 1 y 32 bytes."
        case .invalidPassphrase:
            return "La clave no es válida: debe tener entre 8 y 63 caracteres."
        case .userDenied:
            return "Cancelaste la conexión. Toca «Conectarme» para intentarlo de nuevo."
        case .notInForeground:
            return "La app tiene que estar en primer plano para conectarse."
        case .pending:
            return "Ya hay una conexión en curso. Espera un momento e inténtalo de nuevo."
        case .simulator:
            return "El simulador no puede unirse a redes Wi-Fi. Pruébalo en un iPhone."
        case .failed(let detail):
            return detail
        }
    }
}

/// Se une a la red con `NEHotspotConfigurationManager`. iOS muestra su propio
/// diálogo de confirmación ("¿Quieres conectarte a la red …?").
enum WifiJoiner {
    /// `false` en el simulador, donde NEHotspotConfiguration no funciona.
    static var isSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    /// Aplica la configuración (`joinOnce = false`, la red queda guardada).
    /// `NEHotspotConfigurationError.alreadyAssociated` se considera éxito.
    static func join(_ credentials: TagCredentials) async throws {
        guard isSupported else { throw WifiJoinError.simulator }

        let configuration = try makeConfiguration(for: credentials)
        configuration.joinOnce = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NEHotspotConfigurationManager.shared.apply(configuration) { error in
                guard let error else {
                    continuation.resume()
                    return
                }
                let nsError = error as NSError
                if nsError.domain == NEHotspotConfigurationErrorDomain,
                   nsError.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: Self.mapError(nsError))
                }
            }
        }
    }

    /// Construye la configuración validando antes los límites de iOS
    /// (SSID de 1–32 bytes, clave WPA de 8–63 caracteres o 64 hex).
    static func makeConfiguration(for credentials: TagCredentials) throws -> NEHotspotConfiguration {
        let ssidLength = credentials.ssid.utf8.count
        guard ssidLength >= 1, ssidLength <= 32 else { throw WifiJoinError.invalidSSID }

        if credentials.security.requiresPassword {
            guard isValidWPAPassphrase(credentials.password) else { throw WifiJoinError.invalidPassphrase }
            return NEHotspotConfiguration(ssid: credentials.ssid, passphrase: credentials.password, isWEP: false)
        }
        return NEHotspotConfiguration(ssid: credentials.ssid)
    }

    static func isValidWPAPassphrase(_ passphrase: String) -> Bool {
        let length = passphrase.utf8.count
        if length == 64 {
            return passphrase.allSatisfy { $0.isHexDigit }
        }
        return length >= 8 && length <= 63
    }

    private static func mapError(_ error: NSError) -> WifiJoinError {
        guard error.domain == NEHotspotConfigurationErrorDomain,
              let code = NEHotspotConfigurationError(rawValue: error.code) else {
            return .failed("No se pudo conectar: \(error.localizedDescription)")
        }
        switch code {
        case .userDenied:
            return .userDenied
        case .invalidSSID, .invalidSSIDPrefix:
            return .invalidSSID
        case .invalidWPAPassphrase, .invalidWEPPassphrase:
            return .invalidPassphrase
        case .applicationIsNotInForeground:
            return .notInForeground
        case .pending:
            return .pending
        case .alreadyAssociated:
            // Se trata como éxito antes de llegar acá.
            return .failed("Ya estás conectado a esta red.")
        case .invalid, .invalidEAPSettings, .invalidHS20Settings, .invalidHS20DomainName:
            return .failed("La configuración de la red no es válida.")
        case .systemConfiguration:
            return .failed("iOS no permite configurar redes Wi-Fi en este dispositivo (hay un perfil o una restricción).")
        default:
            return .failed("No se pudo conectar (código \(error.code)). Verifica que el Wi-Fi esté activado e inténtalo de nuevo.")
        }
    }
}
