import Foundation
import Combine

/// Estado de la pantalla "Conectarme". Lo usan la app completa y el App Clip.
@MainActor
final class ConnectViewModel: ObservableObject {
    enum Phase: Equatable {
        /// Esperando una URL de invocación (el clip se abrió sin sticker).
        case idle
        case loading
        case ready
        case connecting
        case connected
        case failed(String)
    }

    @Published private(set) var phase: Phase
    @Published private(set) var credentials: TagCredentials?
    private(set) var tagId: String?

    private let api: TagAPIClient

    init(credentials: TagCredentials? = nil, api: TagAPIClient = TagAPIClient()) {
        self.credentials = credentials
        self.tagId = credentials?.id
        self.phase = credentials == nil ? .idle : .ready
        self.api = api
    }

    var networkName: String { credentials?.name ?? "Red Wi-Fi" }

    var canConnect: Bool {
        guard credentials != nil else { return false }
        switch phase {
        case .ready, .connected, .failed:
            return true
        case .idle, .loading, .connecting:
            return false
        }
    }

    /// Falló la descarga de credenciales: se puede reintentar la descarga.
    var canRetryLoad: Bool {
        if case .failed = phase, credentials == nil, tagId != nil {
            return true
        }
        return false
    }

    /// Procesa la URL con la que se invocó el clip (`/t/<tagId>`).
    func handleInvocation(url: URL) {
        guard let tagId = InvocationURL.tagId(from: url) else {
            phase = .failed("Este enlace no corresponde a un sticker Nova Wi-Fi Tag.")
            return
        }
        Task {
            await self.load(tagId: tagId)
        }
    }

    /// Descarga las credenciales de `/api/tags/<tagId>.json`.
    func load(tagId: String) async {
        self.tagId = tagId
        credentials = nil
        phase = .loading
        do {
            credentials = try await api.fetchCredentials(tagId: tagId)
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func retryLoad() async {
        guard let tagId else { return }
        await load(tagId: tagId)
    }

    /// Usa credenciales ya conocidas (por ejemplo, guardadas en la app).
    func use(_ credentials: TagCredentials) {
        self.credentials = credentials
        self.tagId = credentials.id
        phase = .ready
    }

    /// Pide a iOS unirse a la red.
    func connect() async {
        guard let credentials else { return }
        phase = .connecting
        do {
            try await WifiJoiner.join(credentials)
            phase = .connected
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
