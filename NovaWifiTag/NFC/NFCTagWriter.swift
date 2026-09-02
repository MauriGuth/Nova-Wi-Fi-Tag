import Foundation
#if canImport(CoreNFC)
import CoreNFC
#endif

enum NFCWriteError: LocalizedError {
    case unavailable
    case cancelled
    case notNDEF
    case readOnly
    case tooSmall(capacity: Int, needed: Int)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Este dispositivo no puede grabar etiquetas NFC."
        case .cancelled:
            return "Grabación cancelada."
        case .notNDEF:
            return "El sticker no es compatible con NDEF."
        case .readOnly:
            return "El sticker está bloqueado en modo solo lectura."
        case .tooSmall(let capacity, let needed):
            return "El sticker tiene \(capacity) bytes y el mensaje necesita \(needed). Usa un sticker más grande (NTAG215/216) o desactiva el registro Wi-Fi."
        case .failed(let detail):
            return "No se pudo grabar el sticker: \(detail)"
        }
    }
}

#if canImport(CoreNFC)

/// Graba el mensaje NDEF en un sticker con `NFCNDEFReaderSession`.
final class NFCTagWriter: NSObject {
    static var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    private var session: NFCNDEFReaderSession?
    private var message: NFCNDEFMessage?
    private var continuation: CheckedContinuation<Void, Error>?
    private let lock = NSLock()

    /// Abre la sesión NFC y espera a que el sticker quede grabado (o falle).
    @MainActor
    func write(network: TagCredentials, includeWifi: Bool) async throws {
        guard Self.isAvailable else { throw NFCWriteError.unavailable }
        let message = Self.makeMessage(for: network, includeWifi: includeWifi)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            self.continuation = continuation
            self.message = message
            lock.unlock()

            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            session.alertMessage = "Acerca el iPhone al sticker para grabarlo."
            self.session = session
            session.begin()
        }
    }

    static func makeMessage(for network: TagCredentials, includeWifi: Bool) -> NFCNDEFMessage {
        let payloads = TagMessageBuilder.records(for: network, includeWifi: includeWifi).map { record -> NFCNDEFPayload in
            let format: NFCTypeNameFormat = record.format == .media ? .media : .nfcWellKnown
            return NFCNDEFPayload(format: format, type: record.type, identifier: Data(), payload: record.payload)
        }
        return NFCNDEFMessage(records: payloads)
    }

    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        self.message = nil
        lock.unlock()

        guard let continuation else { return }
        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

extension NFCTagWriter: NFCNDEFReaderSessionDelegate {
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // No se usa: al implementar readerSession(_:didDetect:) iOS entrega los tags ahí.
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            session.alertMessage = "Hay más de un sticker cerca. Deja solo uno y vuelve a acercar el iPhone."
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
                session.restartPolling()
            }
            return
        }

        let pendingMessage = self.message
        guard let tag = tags.first, let message = pendingMessage else {
            session.invalidate(errorMessage: "No se detectó ningún sticker.")
            return
        }

        session.connect(to: tag) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: "No se pudo conectar con el sticker.")
                self?.finish(.failure(NFCWriteError.failed(error.localizedDescription)))
                return
            }

            tag.queryNDEFStatus { [weak self] status, capacity, error in
                if let error {
                    session.invalidate(errorMessage: "No se pudo leer el sticker.")
                    self?.finish(.failure(NFCWriteError.failed(error.localizedDescription)))
                    return
                }

                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Este sticker no es compatible con NDEF.")
                    self?.finish(.failure(NFCWriteError.notNDEF))
                case .readOnly:
                    session.invalidate(errorMessage: "Este sticker es de solo lectura.")
                    self?.finish(.failure(NFCWriteError.readOnly))
                case .readWrite:
                    let needed = message.length
                    guard capacity >= needed else {
                        session.invalidate(errorMessage: "El sticker tiene \(capacity) bytes y se necesitan \(needed).")
                        self?.finish(.failure(NFCWriteError.tooSmall(capacity: capacity, needed: needed)))
                        return
                    }
                    tag.writeNDEF(message) { [weak self] error in
                        if let error {
                            session.invalidate(errorMessage: "No se pudo grabar el sticker.")
                            self?.finish(.failure(NFCWriteError.failed(error.localizedDescription)))
                        } else {
                            session.alertMessage = "¡Sticker grabado!"
                            session.invalidate()
                            self?.finish(.success(()))
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Estado del sticker desconocido.")
                    self?.finish(.failure(NFCWriteError.failed("estado NDEF desconocido")))
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        self.session = nil
        if let readerError = error as? NFCReaderError,
           readerError.code == .readerSessionInvalidationErrorUserCanceled {
            finish(.failure(NFCWriteError.cancelled))
            return
        }
        finish(.failure(NFCWriteError.failed(error.localizedDescription)))
    }
}

#else

/// Plataformas sin CoreNFC (por ejemplo, SDKs sin el framework): la grabación no está disponible.
final class NFCTagWriter: NSObject {
    static var isAvailable: Bool { false }

    @MainActor
    func write(network: TagCredentials, includeWifi: Bool) async throws {
        throw NFCWriteError.unavailable
    }
}

#endif
