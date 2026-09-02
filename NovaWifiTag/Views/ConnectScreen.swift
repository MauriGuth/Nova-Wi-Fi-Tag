import SwiftUI

/// Pantalla "Conectarme" de la app completa. Usa el mismo `ConnectViewModel`
/// y la misma `ConnectCardView` que el App Clip.
struct ConnectScreen: View {
    @EnvironmentObject private var store: NetworkStore
    @StateObject private var model: ConnectViewModel

    private let tagId: String?

    /// Con credenciales ya conocidas (red guardada en la app).
    init(credentials: TagCredentials) {
        _model = StateObject(wrappedValue: ConnectViewModel(credentials: credentials))
        tagId = nil
    }

    /// Con un tagId (enlace universal): usa la red guardada si existe, si no la descarga.
    init(tagId: String) {
        _model = StateObject(wrappedValue: ConnectViewModel())
        self.tagId = tagId
    }

    var body: some View {
        ConnectCardView(model: model)
            .navigationTitle("Conectarme")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard let tagId, model.credentials == nil else { return }
                if let saved = store.network(withId: tagId) {
                    model.use(saved)
                } else {
                    await model.load(tagId: tagId)
                }
            }
    }
}
