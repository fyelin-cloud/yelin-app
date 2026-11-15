import Foundation
import CryptoKit
import AuthenticationServices
import UIKit

enum ErrorDeDrive: LocalizedError {
    case sinConfigurar
    case sinSesion
    case respuesta(String)

    var errorDescription: String? {
        switch self {
        case .sinConfigurar: return "La app se compiló sin el identificador de Google"
        case .sinSesion:     return "Falta iniciar sesión con Google"
        case .respuesta(let detalle): return detalle
        }
    }
}

/// Inicia sesión con Google y sube los archivos de la app a Google Drive.
///
/// Usa el permiso `drive.file`: la app solo puede tocar los archivos que ella
/// misma crea. El resto del Drive le queda invisible.
final class Drive: NSObject {

    static let permiso = "https://www.googleapis.com/auth/drive.file"
    private static let claveDelPermiso = "google_refresh_token"
    private let nombreDeLaCarpeta = "Yelin App"

    private var sesionWeb: ASWebAuthenticationSession?
    private var accesoVigente: (token: String, vence: Date)?
    private var idDeLaCarpeta: String?

    // MARK: Configuración

    /// El identificador lo inserta la compilación desde el secreto de GitHub.
    var identificadorDeCliente: String? {
        guard let valor = Bundle.main.infoDictionary?["GIDClientID"] as? String,
              !valor.isEmpty, !valor.hasPrefix("__") else { return nil }
        return valor
    }

    private var esquemaDeRetorno: String? {
        guard let id = identificadorDeCliente else { return nil }
        return "com.googleusercontent.apps."
            + id.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
    }

    var estaConfigurado: Bool { identificadorDeCliente != nil }
    var haySesion: Bool { Llavero.leer(Self.claveDelPermiso) != nil }

    func cerrarSesion() {
        Llavero.borrar(Self.claveDelPermiso)
        accesoVigente = nil
        idDeLaCarpeta = nil
    }

    // MARK: Inicio de sesión

    @MainActor
    func iniciarSesion() async throws {
        guard let cliente = identificadorDeCliente, let esquema = esquemaDeRetorno else {
            throw ErrorDeDrive.sinConfigurar
        }

        let verificador = Self.textoAleatorio()
        let desafio = Self.desafio(de: verificador)
        let retorno = "\(esquema):/oauth2redirect"

        var partes = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        partes.queryItems = [
            URLQueryItem(name: "client_id", value: cliente),
            URLQueryItem(name: "redirect_uri", value: retorno),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.permiso),
            URLQueryItem(name: "code_challenge", value: desafio),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        let devuelta = try await abrirVentana(partes.url!, esquema: esquema)

        guard let codigo = URLComponents(url: devuelta, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw ErrorDeDrive.respuesta("Google no devolvió el código de autorización")
        }

        let respuesta = try await pedirTokens([
            "code": codigo,
            "client_id": cliente,
            "code_verifier": verificador,
            "grant_type": "authorization_code",
            "redirect_uri": retorno
        ])

        guard let permiso = respuesta["refresh_token"] as? String else {
            throw ErrorDeDrive.respuesta("Google no devolvió el permiso duradero")
        }
        Llavero.guardar(permiso, en: Self.claveDelPermiso)
        guardarAcceso(respuesta)
    }

    @MainActor
    private func abrirVentana(_ url: URL, esquema: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuacion in
            let sesion = ASWebAuthenticationSession(url: url, callbackURLScheme: esquema) { devuelta, error in
                if let devuelta {
                    continuacion.resume(returning: devuelta)
                } else {
                    continuacion.resume(throwing: error ?? ErrorDeDrive.sinSesion)
                }
            }
            sesion.presentationContextProvider = self
            sesion.prefersEphemeralWebBrowserSession = false
            self.sesionWeb = sesion
            sesion.start()
        }
    }

    // MARK: Tokens

    private func guardarAcceso(_ respuesta: [String: Any]) {
        guard let token = respuesta["access_token"] as? String else { return }
        let segundos = (respuesta["expires_in"] as? Double) ?? 3000
        accesoVigente = (token, Date().addingTimeInterval(segundos - 60))
    }

    private func tokenDeAcceso() async throws -> String {
        if let vigente = accesoVigente, vigente.vence > Date() { return vigente.token }

        guard let cliente = identificadorDeCliente else { throw ErrorDeDrive.sinConfigurar }
        guard let permiso = Llavero.leer(Self.claveDelPermiso) else { throw ErrorDeDrive.sinSesion }

        let respuesta = try await pedirTokens([
            "client_id": cliente,
            "refresh_token": permiso,
            "grant_type": "refresh_token"
        ])
        guardarAcceso(respuesta)

        guard let token = accesoVigente?.token else {
            throw ErrorDeDrive.respuesta("Google no renovó el acceso. Volvé a iniciar sesión.")
        }
        return token
    }

    private func pedirTokens(_ campos: [String: String]) async throws -> [String: Any] {
        var pedido = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        pedido.httpMethod = "POST"
        pedido.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = Data(Self.comoFormulario(campos).utf8)

        let (datos, respuesta) = try await URLSession.shared.data(for: pedido)
        guard let http = respuesta as? HTTPURLResponse, http.statusCode == 200 else {
            throw ErrorDeDrive.respuesta(Self.detalleDeError(datos))
        }
        return (try? JSONSerialization.jsonObject(with: datos)) as? [String: Any] ?? [:]
    }

    // MARK: Subida

    /// Sube cada archivo a la carpeta de la app en Drive, creándola si no existe.
    func subir(_ archivos: [URL]) async throws {
        let token = try await tokenDeAcceso()
        let carpeta = try await carpetaDeLaApp(token: token)

        for archivo in archivos {
            guard let contenido = try? Data(contentsOf: archivo) else { continue }
            let nombre = archivo.lastPathComponent
            let id = try await idDelArchivo(nombre: nombre, carpeta: carpeta, token: token)
                ?? crearArchivo(nombre: nombre, carpeta: carpeta, token: token)
            try await subirContenido(contenido, a: id, token: token)
        }
    }

    private func carpetaDeLaApp(token: String) async throws -> String {
        if let idDeLaCarpeta { return idDeLaCarpeta }

        let consulta = "mimeType='application/vnd.google-apps.folder'"
            + " and name='\(nombreDeLaCarpeta)' and trashed=false"
        if let encontrada = try await buscarPrimero(consulta: consulta, token: token) {
            idDeLaCarpeta = encontrada
            return encontrada
        }

        let cuerpo: [String: Any] = [
            "name": nombreDeLaCarpeta,
            "mimeType": "application/vnd.google-apps.folder"
        ]
        let id = try await crear(cuerpo: cuerpo, token: token)
        idDeLaCarpeta = id
        return id
    }

    private func idDelArchivo(nombre: String, carpeta: String, token: String) async throws -> String? {
        try await buscarPrimero(
            consulta: "name='\(nombre)' and '\(carpeta)' in parents and trashed=false",
            token: token)
    }

    private func buscarPrimero(consulta: String, token: String) async throws -> String? {
        var partes = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        partes.queryItems = [
            URLQueryItem(name: "q", value: consulta),
            URLQueryItem(name: "fields", value: "files(id,name)"),
            URLQueryItem(name: "pageSize", value: "10")
        ]
        var pedido = URLRequest(url: partes.url!)
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (datos, respuesta) = try await URLSession.shared.data(for: pedido)
        guard let http = respuesta as? HTTPURLResponse, http.statusCode == 200 else {
            throw ErrorDeDrive.respuesta(Self.detalleDeError(datos))
        }
        let json = (try? JSONSerialization.jsonObject(with: datos)) as? [String: Any]
        let lista = json?["files"] as? [[String: Any]]
        return lista?.first?["id"] as? String
    }

    private func crearArchivo(nombre: String, carpeta: String, token: String) async throws -> String {
        try await crear(cuerpo: ["name": nombre, "parents": [carpeta]], token: token)
    }

    private func crear(cuerpo: [String: Any], token: String) async throws -> String {
        var pedido = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files")!)
        pedido.httpMethod = "POST"
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        pedido.setValue("application/json", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)

        let (datos, respuesta) = try await URLSession.shared.data(for: pedido)
        guard let http = respuesta as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = (try? JSONSerialization.jsonObject(with: datos)) as? [String: Any],
              let id = json["id"] as? String else {
            throw ErrorDeDrive.respuesta(Self.detalleDeError(datos))
        }
        return id
    }

    private func subirContenido(_ contenido: Data, a id: String, token: String) async throws {
        let url = URL(string: "https://www.googleapis.com/upload/drive/v3/files/\(id)?uploadType=media")!
        var pedido = URLRequest(url: url)
        pedido.httpMethod = "PATCH"
        pedido.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        pedido.setValue("text/csv", forHTTPHeaderField: "Content-Type")
        pedido.httpBody = contenido

        let (datos, respuesta) = try await URLSession.shared.data(for: pedido)
        guard let http = respuesta as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ErrorDeDrive.respuesta(Self.detalleDeError(datos))
        }
    }

    // MARK: Ayudas

    private static func detalleDeError(_ datos: Data) -> String {
        if let json = (try? JSONSerialization.jsonObject(with: datos)) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let mensaje = error["message"] as? String {
                return mensaje
            }
            if let descripcion = json["error_description"] as? String { return descripcion }
            if let error = json["error"] as? String { return error }
        }
        return String(data: datos, encoding: .utf8) ?? "Error desconocido de Google"
    }

    private static func comoFormulario(_ campos: [String: String]) -> String {
        var permitidos = CharacterSet.alphanumerics
        permitidos.insert(charactersIn: "-._~")
        return campos.map { clave, valor in
            let v = valor.addingPercentEncoding(withAllowedCharacters: permitidos) ?? valor
            return "\(clave)=\(v)"
        }.joined(separator: "&")
    }

    private static func textoAleatorio() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return enBase64Url(Data(bytes))
    }

    private static func desafio(de verificador: String) -> String {
        enBase64Url(Data(SHA256.hash(data: Data(verificador.utf8))))
    }

    private static func enBase64Url(_ datos: Data) -> String {
        datos.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension Drive: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let ventana = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
        return ventana ?? ASPresentationAnchor()
    }
}
