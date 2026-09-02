import Foundation

/// Un registro NDEF descrito sin depender de CoreNFC (sirve para calcular
/// tamaños en el simulador y para probar la lógica en cualquier plataforma).
struct NDEFRecordSpec: Equatable {
    enum TypeNameFormat: UInt8 {
        case wellKnown = 0x01
        case media = 0x02
    }

    var format: TypeNameFormat
    var type: Data
    var payload: Data

    /// Bytes que ocupa el registro serializado: cabecera (1) + longitud del tipo (1)
    /// + longitud del payload (1 si es Short Record, 4 si no) + tipo + payload. Sin campo ID.
    var encodedSize: Int {
        let payloadLengthField = payload.count < 256 ? 1 : 4
        return 1 + 1 + payloadLengthField + type.count + payload.count
    }
}

/// Arma el mensaje NDEF del sticker: (1) URI del App Clip y (2) credencial WSC para Android.
enum TagMessageBuilder {
    /// Capacidad NDEF útil de un NTAG213.
    static let ntag213Capacity = 137

    struct Summary: Equatable {
        var uriBytes: Int
        var wscBytes: Int
        var totalBytes: Int

        var exceedsNTAG213: Bool { totalBytes > TagMessageBuilder.ntag213Capacity }
    }

    /// Registros en el orden en que se graban: la URL siempre primero
    /// (iOS solo lanza el App Clip si el primer registro es la URL).
    static func records(for credentials: TagCredentials, includeWifi: Bool) -> [NDEFRecordSpec] {
        var records = [uriRecord(for: credentials.tagURL)]
        if includeWifi {
            records.append(wifiRecord(for: credentials))
        }
        return records
    }

    static func summary(for credentials: TagCredentials, includeWifi: Bool) -> Summary {
        let uri = uriRecord(for: credentials.tagURL).encodedSize
        let wsc = includeWifi ? wifiRecord(for: credentials).encodedSize : 0
        return Summary(uriBytes: uri, wscBytes: wsc, totalBytes: uri + wsc)
    }

    static func encodedSize(of records: [NDEFRecordSpec]) -> Int {
        records.reduce(0) { $0 + $1.encodedSize }
    }

    static func uriRecord(for url: URL) -> NDEFRecordSpec {
        NDEFRecordSpec(format: .wellKnown, type: Data("U".utf8), payload: uriPayload(for: url))
    }

    static func wifiRecord(for credentials: TagCredentials) -> NDEFRecordSpec {
        NDEFRecordSpec(format: .media,
                       type: Data(WSCPayload.mimeType.utf8),
                       payload: WSCPayload.build(for: credentials))
    }

    /// Payload del registro URI (NFC Forum RTD-URI): 1 byte de prefijo abreviado + resto de la URL.
    static func uriPayload(for url: URL) -> Data {
        let absolute = url.absoluteString
        let prefixes: [(code: UInt8, text: String)] = [
            (0x01, "http://www."),
            (0x02, "https://www."),
            (0x03, "http://"),
            (0x04, "https://"),
        ]
        for prefix in prefixes where absolute.hasPrefix(prefix.text) {
            return Data([prefix.code]) + Data(absolute.dropFirst(prefix.text.count).utf8)
        }
        return Data([0x00]) + Data(absolute.utf8)
    }
}
