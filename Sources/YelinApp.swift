import SwiftUI
import UIKit

@main
struct AplicacionYelin: App {
    var body: some Scene {
        WindowGroup {
            PantallaDePrueba()
        }
    }
}

struct PantallaDePrueba: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Funciona")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Paso 1 listo: del código a tu pantalla.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 0) {
                Fila(titulo: "Aparato", valor: Info.modelo)
                Divider()
                Fila(titulo: "Sistema", valor: Info.sistema)
                Divider()
                Fila(titulo: "Versión", valor: Info.version)
            }
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(32)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct Fila: View {
    let titulo: String
    let valor: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo)
                .foregroundColor(.secondary)
            Spacer(minLength: 16)
            Text(valor)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
    }
}

enum Info {
    static var modelo: String {
        var datos = utsname()
        uname(&datos)
        let identificador = withUnsafePointer(to: &datos.machine) { puntero in
            String(cString: UnsafeRawPointer(puntero).assumingMemoryBound(to: CChar.self))
        }
        return "\(UIDevice.current.model) (\(identificador))"
    }

    static var sistema: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    static var version: String {
        let datos = Bundle.main.infoDictionary
        let corta = datos?["CFBundleShortVersionString"] as? String ?? "?"
        let compilacion = datos?["CFBundleVersion"] as? String ?? "?"
        return "\(corta) · compilación \(compilacion)"
    }
}
