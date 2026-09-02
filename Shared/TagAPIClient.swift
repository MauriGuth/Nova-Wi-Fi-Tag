import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // solo Linux (tests); no-op en Apple
#endif

enum TagAPIError: LocalizedError {
    case invalidTagId
    case notFound
    case badStatus(Int)
    case decoding
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidTagId:
            return "El código del sticker no es válido."
        case .notFound:
            return "Este sticker no está registrado en el servidor."
        case .badStatus(let code):
            return "El servidor respondió con un error (\(code)). Inténtalo de nuevo."
        case .decoding:
            return "No se pudieron leer los datos de la red."
        case .transport(let error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                    return "No hay conexión a internet. Activa los datos móviles e inténtalo de nuevo."
                case .timedOut:
                    return "El servidor tardó demasiado en responder. Inténtalo de nuevo."
                default:
                    break
                }
            }
            return "No se pudo contactar al servidor. \(error.localizedDescription)"
        }
    }
}

/// Cliente mínimo para `GET https://wifi.novasolutions.ar/api/tags/<tagId>.json`.
struct TagAPIClient {
    let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: configuration)
        }
    }

    func fetchCredentials(tagId: String) async throws -> TagCredentials {
        guard TagCredentials.isValidTagId(tagId) else { throw TagAPIError.invalidTagId }

        var request = URLRequest(url: NovaConfig.apiURL(for: tagId))
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            throw TagAPIError.transport(error)
        }
        let (data, response) = result

        guard let http = response as? HTTPURLResponse else { throw TagAPIError.badStatus(0) }
        switch http.statusCode {
        case 200:
            break
        case 404:
            throw TagAPIError.notFound
        default:
            throw TagAPIError.badStatus(http.statusCode)
        }

        do {
            var credentials = try JSONDecoder().decode(TagCredentials.self, from: data)
            if credentials.id.isEmpty {
                credentials.id = tagId
            }
            return credentials
        } catch {
            throw TagAPIError.decoding
        }
    }
}
