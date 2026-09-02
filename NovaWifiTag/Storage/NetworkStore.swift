import Foundation
import Combine

/// Referencia a un sticker recibido por enlace universal (para presentar "Conectarme").
struct TagReference: Identifiable, Hashable {
    let id: String
}

/// Lista local de redes, persistida en el Keychain.
@MainActor
final class NetworkStore: ObservableObject {
    @Published private(set) var networks: [TagCredentials] = []
    @Published var pendingTag: TagReference?
    @Published var errorMessage: String?

    init() {
        load()
    }

    func load() {
        do {
            guard let data = try KeychainStorage.read() else {
                networks = []
                return
            }
            networks = try JSONDecoder().decode([TagCredentials].self, from: data)
        } catch {
            networks = []
            errorMessage = "No se pudieron leer las redes guardadas. \(error.localizedDescription)"
        }
    }

    func network(withId id: String) -> TagCredentials? {
        networks.first { $0.id == id }
    }

    /// Agrega o reemplaza (por `id`).
    func upsert(_ network: TagCredentials) {
        if let index = networks.firstIndex(where: { $0.id == network.id }) {
            networks[index] = network
        } else {
            networks.append(network)
        }
        persist()
    }

    func delete(id: String) {
        networks.removeAll { $0.id == id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        networks.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(networks)
            try KeychainStorage.write(data)
        } catch {
            errorMessage = "No se pudieron guardar las redes. \(error.localizedDescription)"
        }
    }
}
