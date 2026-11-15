import Foundation
import HealthKit

/// Escribe el peso en Salud de Apple.
///
/// Salud es solo una cañería: Google Health levanta de ahí el peso, que es la
/// interfaz que Facundo prefiere. La app no lee nada de Salud.
///
/// Atención: este permiso puede no estar disponible firmando con una cuenta de
/// Apple gratuita. La pantalla muestra en qué estado quedó.
final class Salud {

    private let almacen = HKHealthStore()
    private let tipoPeso = HKQuantityType(.bodyMass)

    var disponible: Bool { HKHealthStore.isHealthDataAvailable() }

    func estadoDelPermiso() -> String {
        guard disponible else { return "No disponible en este aparato" }
        switch almacen.authorizationStatus(for: tipoPeso) {
        case .sharingAuthorized: return "Autorizado"
        case .sharingDenied:     return "Rechazado"
        case .notDetermined:     return "Sin pedir todavía"
        @unknown default:        return "Desconocido"
        }
    }

    func pedirPermiso(_ avisar: @escaping (String) -> Void) {
        guard disponible else {
            avisar("Salud no está disponible en este aparato")
            return
        }
        let aEscribir: Set<HKSampleType> = [tipoPeso]
        almacen.requestAuthorization(toShare: aEscribir, read: Set<HKObjectType>()) { concedido, error in
            DispatchQueue.main.async {
                if let error {
                    avisar("Falló el pedido: \(error.localizedDescription)")
                } else {
                    avisar(concedido ? "Permiso dado" : "Permiso rechazado")
                }
            }
        }
    }

    func guardar(_ pesada: Pesada, _ avisar: @escaping (String) -> Void) {
        guard disponible else {
            avisar("Salud no está disponible")
            return
        }
        let cantidad = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: pesada.kg)
        let muestra = HKQuantitySample(type: tipoPeso,
                                       quantity: cantidad,
                                       start: pesada.instante,
                                       end: pesada.instante)
        almacen.save(muestra) { guardado, error in
            DispatchQueue.main.async {
                if guardado {
                    avisar(String(format: "Mandado a Salud: %.2f kg", pesada.kg))
                } else {
                    avisar("No se pudo guardar: \(error?.localizedDescription ?? "sin detalle")")
                }
            }
        }
    }
}
