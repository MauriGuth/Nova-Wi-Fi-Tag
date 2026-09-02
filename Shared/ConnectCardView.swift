import SwiftUI

/// Pantalla "Conectarme": nombre de la red, estado y el botón grande.
/// Es la misma vista en la app completa y en el App Clip.
struct ConnectCardView: View {
    @ObservedObject var model: ConnectViewModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 132, height: 132)
                Image(systemName: iconName)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 6) {
                Text(model.networkName)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                if let ssid = model.credentials?.ssid, ssid != model.networkName {
                    Text(ssid)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            statusView
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            if model.canRetryLoad {
                Button {
                    Task { await model.retryLoad() }
                } label: {
                    Text("Reintentar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    Task { await model.connect() }
                } label: {
                    HStack(spacing: 10) {
                        if model.phase == .connecting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(buttonTitle)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canConnect)
            }

            Text("iOS te pedirá confirmación antes de unirse a la red.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private var buttonTitle: String {
        switch model.phase {
        case .connecting:
            return "Conectando…"
        case .connected:
            return "Conectado"
        default:
            return "Conectarme a \(model.networkName)"
        }
    }

    private var iconName: String {
        switch model.phase {
        case .connected:
            return "checkmark.circle.fill"
        case .failed:
            return "wifi.exclamationmark"
        default:
            return "wifi"
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.phase {
        case .idle:
            Label("Acerca tu iPhone a un sticker Nova Wi-Fi Tag para empezar.", systemImage: "sensor.tag.radiowaves.forward")
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Buscando la red…")
            }
            .foregroundStyle(.secondary)
        case .ready:
            Label("Listo para conectar", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .connecting:
            HStack(spacing: 8) {
                ProgressView()
                Text("Conectando…")
            }
            .foregroundStyle(.secondary)
        case .connected:
            Label("Conectado. Ya puedes usar el Wi-Fi.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}
