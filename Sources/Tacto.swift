import UIKit

/// El golpecito que confirma que algo quedó guardado.
///
/// Sirve sobre todo cuando no se está mirando la pantalla: al bajarse de la
/// balanza o al anotar una serie entre repeticiones.
enum Tacto {
    static func guardado() {
        let aviso = UINotificationFeedbackGenerator()
        aviso.prepare()
        aviso.notificationOccurred(.success)
    }

    static func toque() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
