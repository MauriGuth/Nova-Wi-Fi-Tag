import SwiftUI
import Combine

@MainActor
final class WriteTagViewModel: ObservableObject {
    @Published var isWriting = false
    @Published var resultMessage: String?
    @Published var showingResult = false

    private let writer = NFCTagWriter()

    var isNFCAvailable: Bool { NFCTagWriter.isAvailable }

    func write(network: TagCredentials, includeWifi: Bool) async {
        guard !isWriting else { return }
        isWriting = true
        defer { isWriting = false }

        do {
            try await writer.write(network: network, includeWifi: includeWifi)
            resultMessage = "Sticker grabado. Pruébalo acercando un iPhone."
            showingResult = true
        } catch NFCWriteError.cancelled {
            return
        } catch {
            resultMessage = error.localizedDescription
            showingResult = true
        }
    }
}

/// Pantalla "Grabar sticker": muestra los registros NDEF, el tamaño en bytes
/// y graba el sticker con CoreNFC.
struct WriteTagView: View {
    let network: TagCredentials

    @StateObject private var model = WriteTagViewModel()
    @State private var includeWifiRecord = true

    private var summary: TagMessageBuilder.Summary {
        TagMessageBuilder.summary(for: network, includeWifi: includeWifiRecord)
    }

    var body: some View {
        List {
            Section("Contenido del sticker") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1 · URL (abre el App Clip)")
                        .font(.subheadline.bold())
                    Text(network.tagURL.absoluteString)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Toggle(isOn: $includeWifiRecord) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("2 · Red Wi-Fi (Android)")
                            .font(.subheadline.bold())
                        Text("Registro application/vnd.wfa.wsc con SSID, seguridad y clave. Android se conecta solo al tocar el sticker.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Tamaño") {
                LabeledContent("Registro URL", value: "\(summary.uriBytes) bytes")
                if includeWifiRecord {
                    LabeledContent("Registro Wi-Fi", value: "\(summary.wscBytes) bytes")
                }
                LabeledContent("Mensaje NDEF total", value: "\(summary.totalBytes) bytes")
                if summary.exceedsNTAG213 {
                    Label("Supera los \(TagMessageBuilder.ntag213Capacity) bytes de un NTAG213. Usa un NTAG215/216 o desactiva el registro Wi-Fi.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Label("Entra en un NTAG213 (\(TagMessageBuilder.ntag213Capacity) bytes).", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section {
                Button {
                    Task { await model.write(network: network, includeWifi: includeWifiRecord) }
                } label: {
                    HStack {
                        Spacer()
                        if model.isWriting {
                            ProgressView()
                        } else {
                            Label("Grabar sticker", systemImage: "wave.3.right")
                        }
                        Spacer()
                    }
                }
                .disabled(!model.isNFCAvailable || model.isWriting)
            } footer: {
                if model.isNFCAvailable {
                    Text("Se graba primero la URL y después la red Wi-Fi: iOS solo muestra el App Clip si el primer registro es la URL.")
                } else {
                    Text("Este dispositivo no puede grabar NFC (o estás en el simulador).")
                }
            }
        }
        .navigationTitle("Grabar sticker")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Grabar sticker", isPresented: $model.showingResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.resultMessage ?? "")
        }
    }
}
