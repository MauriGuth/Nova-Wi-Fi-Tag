import SwiftUI

/// App Clip: se invoca al tocar un sticker NFC (o abrir la URL) y muestra una
/// sola pantalla para unirse a la red.
@main
struct NovaWifiTagClipApp: App {
    @StateObject private var model = ConnectViewModel()

    var body: some Scene {
        WindowGroup {
            ClipRootView(model: model)
                // iOS entrega la URL de invocación (https://wifi.novasolutions.ar/t/<tagId>)
                // como NSUserActivity de tipo NSUserActivityTypeBrowsingWeb.
                // Desde Xcode se simula con la variable de entorno _XCAppClipURL del scheme.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    model.handleInvocation(url: url)
                }
                .onOpenURL { url in
                    model.handleInvocation(url: url)
                }
        }
    }
}
