import Foundation
import Network
import NetworkExtension

enum WifiJoinError: LocalizedError {
    case invalidSSID
    case invalidPassphrase
    case userDenied
    case notInForeground
    case pending
    case simulator
    /// iOS aceptó la configuración pero el iPhone no quedó unido a esa red.
    case notJoined(ssid: String)
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
        case .notJoined(let ssid):
            return "El iPhone no logró unirse a «\(ssid)». Verifica que la red esté cerca, que la clave sea correcta y vuelve a intentarlo."
        case .failed(let detail):
            return detail
        }
    }
}

/// Se une a la red con `NEHotspotConfigurationManager`. iOS muestra su propio
/// diálogo de confirmación ("¿Quieres conectarte a la red …?").
enum WifiJoiner {
    /// Cómo comprobar, después de `apply`, que la unión a la red funcionó.
    enum Verification {
        /// Compara el SSID actual con `NEHotspotNetwork.fetchCurrent`. Requiere el entitlement
        /// `com.apple.developer.networking.wifi-info` (Access Wi-Fi Information). Lo usa la app.
        case ssid
        /// Solo comprueba que haya una ruta Wi-Fi utilizable (`NWPathMonitor`). Lo usa el App Clip,
        /// que no puede tener el entitlement wifi-info. No distingue entre "se unió a esta red" y
        /// "ya estaba en otra red Wi-Fi", pero detecta el caso típico del invitado que venía por datos.
        case wifiInterface
    }

    /// `false` en el simulador, donde NEHotspotConfiguration no funciona.
    static var isSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    /// Aplica la configuración (`joinOnce = false`, la red queda guardada) y después
    /// comprueba que el iPhone realmente haya quedado unido a ese SSID.
    /// `NEHotspotConfigurationError.alreadyAssociated` se considera éxito.
    ///
    /// La comprobación existe porque `apply` puede terminar sin error aunque iOS muestre
    /// "No se pudo conectar a la red" (clave incorrecta, red fuera de alcance, SSID inexistente).
    static func join(_ credentials: TagCredentials, verification: Verification = .ssid) async throws {
        guard isSupported else { throw WifiJoinError.simulator }

        let configuration = try makeConfiguration(for: credentials)
        configuration.joinOnce = false

        let alreadyAssociated = try await apply(configuration)
        if alreadyAssociated {
            return
        }
        let joined: Bool
        switch verification {
        case .ssid:
            joined = await waitUntilJoined(ssid: credentials.ssid)
        case .wifiInterface:
            joined = await waitForWifiPath()
        }
        guard joined else {
            // Limpia la configuración que no sirvió para que el próximo intento parta de cero.
            NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: credentials.ssid)
            throw WifiJoinError.notJoined(ssid: credentials.ssid)
        }
    }

    /// Devuelve `true` si iOS respondió `alreadyAssociated` (ya estaba en esa red).
    private static func apply(_ configuration: NEHotspotConfiguration) async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            NEHotspotConfigurationManager.shared.apply(configuration) { error in
                guard let error else {
                    continuation.resume(returning: false)
                    return
                }
                let nsError = error as NSError
                if nsError.domain == NEHotspotConfigurationErrorDomain,
                   nsError.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(throwing: Self.mapError(nsError))
                }
            }
        }
    }

    /// SSID de la red Wi-Fi actual. Requiere el entitlement
    /// `com.apple.developer.networking.wifi-info` (Access Wi-Fi Information) y que la app haya
    /// configurado esa red con NEHotspotConfiguration; en cualquier otro caso devuelve `nil`.
    static func currentSSID() async -> String? {
        await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            NEHotspotNetwork.fetchCurrent { network in
                continuation.resume(returning: network?.ssid)
            }
        }
    }

    /// Espera hasta que haya una ruta de red por Wi-Fi utilizable (sin mirar el SSID).
    private static func waitForWifiPath(attempts: Int = 10) async -> Bool {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor.start(queue: DispatchQueue(label: "ar.novasolutions.wifitag.wifi-path"))
        defer { monitor.cancel() }
        for _ in 0..<attempts {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if monitor.currentPath.status == .satisfied {
                return true
            }
        }
        return false
    }

    /// Consulta la red actual durante unos segundos hasta que coincida con `ssid`.
    private static func waitUntilJoined(ssid: String, attempts: Int = 10) async -> Bool {
        for _ in 0..<attempts {
            if await currentSSID() == ssid {
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        return false
    }

    /// Construye la configuración validando antes los límites de iOS
    /// (SSID de 1–32 bytes, clave WPA de 8–63 caracteres).
    static func makeConfiguration(for credentials: TagCredentials) throws -> NEHotspotConfiguration {
        let ssidLength = credentials.ssid.utf8.count
        guard ssidLength >= 1, ssidLength <= 32 else { throw WifiJoinError.invalidSSID }

        if credentials.security.requiresPassword {
            guard isValidWPAPassphrase(credentials.password) else { throw WifiJoinError.invalidPassphrase }
            return NEHotspotConfiguration(ssid: credentials.ssid, passphrase: credentials.password, isWEP: false)
        }
        return NEHotspotConfiguration(ssid: credentials.ssid)
    }

    /// NEHotspotConfiguration solo acepta frases de 8 a 63 caracteres (no la PSK de 64 hex).
    static func isValidWPAPassphrase(_ passphrase: String) -> Bool {
        let length = passphrase.utf8.count
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
