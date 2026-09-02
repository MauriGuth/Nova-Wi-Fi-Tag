import SwiftUI

@main
struct NovaWifiTagApp: App {
    @StateObject private var store = NetworkStore()

    var body: some Scene {
        WindowGroup {
            NetworkListView()
                .environmentObject(store)
                // Con la app instalada, el sticker abre la app por enlace universal
                // (applinks:wifi.novasolutions.ar). Se muestra la misma pantalla que el clip.
                .onOpenURL { url in
                    handle(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    handle(url)
                }
        }
    }

    private func handle(_ url: URL) {
        guard let tagId = InvocationURL.tagId(from: url) else { return }
        store.pendingTag = TagReference(id: tagId)
    }
}
