import SwiftUI

/// Alta / edición de una red.
struct NetworkFormView: View {
    @EnvironmentObject private var store: NetworkStore
    @Environment(\.dismiss) private var dismiss

    private let original: TagCredentials?

    @State private var name: String
    @State private var ssid: String
    @State private var password: String
    @State private var security: WifiSecurity
    @State private var tagId: String
    @State private var showPassword = false

    init(network: TagCredentials?) {
        original = network
        _name = State(initialValue: network?.name ?? "")
        _ssid = State(initialValue: network?.ssid ?? "")
        _password = State(initialValue: network?.password ?? "")
        _security = State(initialValue: network?.security ?? .wpa2)
        _tagId = State(initialValue: network?.id ?? "")
    }

    private var isEditing: Bool { original != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Red") {
                    TextField("Nombre (ej. Wi-Fi de Mauri)", text: $name)
                    TextField("SSID", text: $ssid)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Seguridad", selection: $security) {
                        ForEach(WifiSecurity.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    if security.requiresPassword {
                        HStack {
                            if showPassword {
                                TextField("Clave", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("Clave", text: $password)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Section {
                    TextField("Tag ID (ej. casa)", text: $tagId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isEditing)
                } header: {
                    Text("Sticker")
                } footer: {
                    Text("Solo letras, números, guion y guion bajo. Es el <tagId> de https://\(NovaConfig.host)/t/<tagId> y tiene que existir en el servidor (api/tags/<tagId>.json) para que el App Clip lo encuentre.")
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar red" : "Nueva red")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        save()
                    }
                    .disabled(validationMessage != nil)
                }
            }
        }
    }

    private var validationMessage: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Ponle un nombre a la red."
        }
        let ssidLength = ssid.utf8.count
        if ssidLength < 1 || ssidLength > 32 {
            return "El SSID debe tener entre 1 y 32 bytes."
        }
        if security.requiresPassword, !WifiJoiner.isValidWPAPassphrase(password) {
            return "La clave debe tener entre 8 y 63 caracteres."
        }
        if !TagCredentials.isValidTagId(tagId) {
            return "El Tag ID solo puede tener letras, números, guion y guion bajo (máximo 64)."
        }
        if !isEditing, store.network(withId: tagId) != nil {
            return "Ya existe una red con ese Tag ID."
        }
        return nil
    }

    private func save() {
        let credentials = TagCredentials(
            id: tagId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            ssid: ssid,
            password: security.requiresPassword ? password : "",
            security: security
        )
        store.upsert(credentials)
        dismiss()
    }
}
