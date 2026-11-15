import Foundation
import Security

/// Guarda datos sensibles en el llavero del aparato.
///
/// Acá va el permiso que devuelve Google al iniciar sesión. No sale del iPad:
/// no pasa por el repositorio, ni por la compilación, ni por ningún servidor.
enum Llavero {

    @discardableResult
    static func guardar(_ valor: String, en clave: String) -> Bool {
        let datos = Data(valor.utf8)
        borrar(clave)
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: clave,
            kSecValueData as String: datos,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        return SecItemAdd(consulta as CFDictionary, nil) == errSecSuccess
    }

    static func leer(_ clave: String) -> String? {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: clave,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var resultado: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data else { return nil }
        return String(data: datos, encoding: .utf8)
    }

    @discardableResult
    static func borrar(_ clave: String) -> Bool {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: clave
        ]
        return SecItemDelete(consulta as CFDictionary) == errSecSuccess
    }
}
