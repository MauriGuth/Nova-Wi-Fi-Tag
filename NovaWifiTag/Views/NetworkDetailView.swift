import SwiftUI
import UIKit

/// Detalle de una red: datos, "Conectarme" y "Grabar sticker".
struct NetworkDetailView: View {
    @EnvironmentObject private var store: NetworkStore
    @Environment(\.dismiss) private var dismiss

    let networkId: String

    @State private var editing = false
    @State private var confirmingDelete = false
    @State private var copiedURL = false

    var body: some View {
        if let network = store.network(withId: networkId) {
            List {
                Section("Red") {
                    LabeledContent("Nombre", value: network.name)
                    LabeledContent("SSID", value: network.ssid)
                    LabeledContent("Seguridad", value: network.security.displayName)
                    if network.security.requiresPassword {
                        PasswordRow(password: network.password)
                    }
                }

                Section("Sticker") {
                    LabeledContent("Tag ID", value: network.id)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("URL")
                        Text(network.tagURL.absoluteString)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Button {
                        UIPasteboard.general.string = network.tagURL.absoluteString
                        copiedURL = true
                    } label: {
                        Label(copiedURL ? "URL copiada" : "Copiar URL", systemImage: "doc.on.doc")
                    }
                }

                Section {
                    NavigationLink {
                        ConnectScreen(credentials: network)
                    } label: {
                        Label("Conectarme", systemImage: "wifi")
                    }
                    NavigationLink {
                        WriteTagView(network: network)
                    } label: {
                        Label("Grabar sticker", systemImage: "wave.3.right")
                    }
                }

                Section {
                    Button("Eliminar red", role: .destructive) {
                        confirmingDelete = true
                    }
                }
            }
            .navigationTitle(network.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Editar") {
                        editing = true
                    }
                }
            }
            .sheet(isPresented: $editing) {
                NetworkFormView(network: network)
            }
            .confirmationDialog("¿Eliminar esta red?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    store.delete(id: network.id)
                    dismiss()
                }
            } message: {
                Text("Se borra solo de esta app. Los stickers ya grabados siguen funcionando mientras exista api/tags/\(network.id).json en el servidor.")
            }
        } else {
            Text("Esta red ya no existe.")
                .foregroundStyle(.secondary)
        }
    }
}

struct PasswordRow: View {
    let password: String
    @State private var revealed = false

    var body: some View {
        LabeledContent("Clave") {
            HStack(spacing: 10) {
                Text(revealed ? password : String(repeating: "•", count: max(8, min(password.count, 16))))
                    .font(.body.monospaced())
                Button {
                    revealed.toggle()
                } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
