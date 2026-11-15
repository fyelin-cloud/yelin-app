import Foundation
import UserNotifications

/// Lleva la cuenta de los siete días que dura la firma de la app.
///
/// AltStore firma con un Apple ID gratuito y esa firma caduca a la semana.
/// La app no puede saber la fecha exacta de la firma, así que usa la primera
/// vez que se abrió esta compilación, que en la práctica es el mismo día.
enum Firma {

    static let diasQueDura = 7

    private static var clave: String {
        let compilacion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "instalada-\(compilacion)"
    }

    /// Se llama al abrir la app. La primera vez de cada compilación, anota la fecha.
    @discardableResult
    static func registrar() -> Date {
        let guardadas = UserDefaults.standard
        if let anotada = guardadas.object(forKey: clave) as? Date { return anotada }
        let ahora = Date()
        guardadas.set(ahora, forKey: clave)
        return ahora
    }

    static var instalada: Date { registrar() }

    static var vence: Date {
        Calendar.current.date(byAdding: .day, value: diasQueDura, to: instalada) ?? instalada
    }

    static var diasRestantes: Int {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())
        let dia = calendario.startOfDay(for: vence)
        return calendario.dateComponents([.day], from: hoy, to: dia).day ?? 0
    }

    static var resumen: String {
        let dias = diasRestantes
        switch dias {
        case ..<0:  return "Vencida"
        case 0:     return "Vence hoy"
        case 1:     return "Vence mañana"
        default:    return "Quedan \(dias) días"
        }
    }

    // MARK: Aviso

    static func estadoDelAviso(_ avisar: @escaping (String) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { ajustes in
            DispatchQueue.main.async {
                switch ajustes.authorizationStatus {
                case .authorized, .provisional: avisar("Activado")
                case .denied:                   avisar("Rechazado en Configuración")
                default:                        avisar("Sin activar")
                }
            }
        }
    }

    /// Pide permiso y programa dos avisos: uno el día antes y otro el día que vence.
    static func programar(_ avisar: @escaping (String) -> Void) {
        let centro = UNUserNotificationCenter.current()
        centro.requestAuthorization(options: [.alert, .sound]) { concedido, error in
            DispatchQueue.main.async {
                if let error {
                    avisar("No se pudo: \(error.localizedDescription)")
                    return
                }
                guard concedido else {
                    avisar("Permiso rechazado")
                    return
                }
                armar(centro)
                avisar("Activado")
            }
        }
    }

    private static func armar(_ centro: UNUserNotificationCenter) {
        centro.removePendingNotificationRequests(withIdentifiers: ["firma-antes", "firma-dia"])

        let calendario = Calendar.current
        let avisos: [(String, Date?, String, String)] = [
            ("firma-antes",
             calendario.date(byAdding: .day, value: -1, to: vence),
             "Mañana vence Yelin App",
             "Prendé AltServer en la PC y renovala desde AltStore."),
            ("firma-dia",
             vence,
             "Hoy vence Yelin App",
             "Si no la renovás, deja de abrir. Los datos no se pierden.")
        ]

        for (id, fecha, titulo, cuerpo) in avisos {
            guard var fecha else { continue }
            // A las 10 de la mañana, que es una hora razonable para avisar.
            fecha = calendario.date(bySettingHour: 10, minute: 0, second: 0, of: fecha) ?? fecha
            guard fecha > Date() else { continue }

            let contenido = UNMutableNotificationContent()
            contenido.title = titulo
            contenido.body = cuerpo
            contenido.sound = .default

            let partes = calendario.dateComponents([.year, .month, .day, .hour, .minute], from: fecha)
            let cuando = UNCalendarNotificationTrigger(dateMatching: partes, repeats: false)
            centro.add(UNNotificationRequest(identifier: id, content: contenido, trigger: cuando))
        }
    }
}
