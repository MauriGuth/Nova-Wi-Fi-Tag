import SwiftUI
import UIKit

struct ClipRootView: View {
    @ObservedObject var model: ConnectViewModel

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            ConnectCardView(model: model)
        }
    }
}
