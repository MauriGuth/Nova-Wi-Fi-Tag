import SwiftUI

/// Pantalla principal de la app: lista de redes guardadas en el Keychain.
struct NetworkListView: View {
    @EnvironmentObject private var store: NetworkStore
    @State private var showingForm = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Mis redes")
                .navigationDestination(for: String.self) { networkId in
                    NetworkDetailView(networkId: networkId)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingForm = true
                        } label: {
                            Label("Agregar red", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingForm) {
                    NetworkFormView(network: nil)
                }
                // Llegó un enlace universal /t/<tagId>: misma pantalla que el App Clip.
                .sheet(item: $store.pendingTag) { reference in
                    NavigationStack {
                        ConnectScreen(tagId: reference.id)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cerrar") {
                                        store.pendingTag = nil
                                    }
                                }
                            }
                    }
                }
                .alert("Error", isPresented: errorPresented) {
                    Button("OK", role: .cancel) {
                        store.errorMessage = nil
                    }
                } message: {
                    Text(store.errorMessage ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.networks.isEmpty {
            EmptyNetworksView {
                showingForm = true
            }
        } else {
            List {
                Section {
                    ForEach(store.networks) { network in
                        NavigationLink(value: network.id) {
                            NetworkRow(network: network)
                        }
                    }
                    .onDelete { offsets in
                        store.delete(at: offsets)
                    }
                } footer: {
                    Text("Desliza una red hacia la izquierda para eliminarla.")
                }
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { presented in
                if !presented {
                    store.errorMessage = nil
                }
            }
        )
    }
}

struct NetworkRow: View {
    let network: TagCredentials

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(network.name)
                .font(.headline)
            HStack(spacing: 6) {
                Text(network.ssid)
                    .font(.subheadline.monospaced())
                Text("·")
                Text(network.security.displayName)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            Text("Sticker: \(network.id)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

struct EmptyNetworksView: View {
    var addAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("Todavía no hay redes")
                .font(.title2.bold())
            Text("Agrega tu red Wi-Fi para conectarte desde la app y grabar stickers NFC para tus invitados.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Agregar red", action: addAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
    }
}
