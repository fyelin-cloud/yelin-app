import SwiftUI
import UIKit

@main
struct AplicacionYelin: App {
    @StateObject private var balanza = LectorDeBalanza()

    var body: some Scene {
        WindowGroup {
            PantallaBalanza(balanza: balanza)
        }
    }
}

struct PantallaBalanza: View {
    @ObservedObject var balanza: LectorDeBalanza
    @State private var copiado = false

    var body: some View {
        VStack(spacing: 28) {
            Text("Balanza")
                .font(.title2)
                .fontWeight(.semibold)

            peso

            Text(balanza.estado)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 44)

            tramas

            botones

            Text("Yelin App \(Info.version)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var peso: some View {
        VStack(spacing: 4) {
            if let kg = balanza.pesoKg {
                Text(String(format: "%.2f", kg))
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("kg")
                    .font(.title3)
                    .foregroundColor(.secondary)
            } else {
                Text("—")
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Text("sin lectura")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var tramas: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tramas recibidas")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(balanza.cantidadDeTramas)")
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            if !balanza.ultimaTrama.isEmpty {
                Text(balanza.ultimaTrama)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var botones: some View {
        VStack(spacing: 12) {
            Button("Buscar la balanza de nuevo") {
                balanza.buscarDeNuevo()
            }
            .buttonStyle(.borderedProminent)

            Button(copiado ? "Copiado" : "Copiar las tramas") {
                UIPasteboard.general.string = balanza.textoParaCopiar()
                copiado = true
            }
            .disabled(balanza.cantidadDeTramas == 0)
        }
    }
}

enum Info {
    static var version: String {
        let datos = Bundle.main.infoDictionary
        let corta = datos?["CFBundleShortVersionString"] as? String ?? "?"
        let compilacion = datos?["CFBundleVersion"] as? String ?? "?"
        return "\(corta) · compilación \(compilacion)"
    }
}
