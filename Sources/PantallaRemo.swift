import SwiftUI
import UIKit

struct PantallaRemo: View {
    @ObservedObject var remo: LectorDeRemo
    @State private var copiado = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    distancia
                }

                Section("Lo que manda la máquina") {
                    Fila("Ritmo por 500 m", enMinutos(remo.datos.ritmoPor500))
                    Fila("Paladas por minuto", sinNada(remo.datos.paladasPorMinuto))
                    Fila("Watts", sinNada(remo.datos.watts))
                    Fila("Paladas totales", sinNada(remo.datos.paladasTotales))
                }

                Section("Lo que calcula la app") {
                    Fila("Tiempo remando", enMinutos(Int(remo.segundosRemando)))
                    Fila("Tiempo total", enMinutos(Int(remo.segundosTotales)))
                    Fila("Watts promedio", String(format: "%.0f", remo.wattsPromedioCalculado))
                    Button(role: .destructive) {
                        remo.reiniciarSesion()
                    } label: {
                        Label("Reiniciar la sesión", systemImage: "arrow.counterclockwise")
                    }
                }

                Section("Conexión") {
                    Fila("Estado", remo.estado)
                    if !remo.nombreDelAparato.isEmpty {
                        Fila("Aparato", remo.nombreDelAparato)
                    }
                    Button {
                        remo.buscarDeNuevo()
                    } label: {
                        Label("Buscar la máquina de nuevo", systemImage: "arrow.clockwise")
                    }
                }

                Section("Tramas crudas") {
                    Fila("Recibidas", "\(remo.cantidadDeTramas)")
                    if !remo.ultimaTrama.isEmpty {
                        Text(remo.ultimaTrama)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Button {
                        UIPasteboard.general.string = remo.textoParaCopiar()
                        copiado = true
                    } label: {
                        Label(copiado ? "Copiado" : "Copiar las tramas",
                              systemImage: "doc.on.doc")
                    }
                    .disabled(remo.cantidadDeTramas == 0)
                }
            }
            .navigationTitle("Remo")
        }
        .navigationViewStyle(.stack)
    }

    private var distancia: some View {
        VStack(spacing: 6) {
            let metros = Int(remo.distanciaCalculada)
            Text("\(metros)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("metros")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("faltan \(max(0, 10_000 - metros)) para los 10 000")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func enMinutos(_ segundos: Int?) -> String {
        guard let segundos else { return "—" }
        return String(format: "%d:%02d", segundos / 60, segundos % 60)
    }

    private func sinNada(_ valor: Int?) -> String {
        guard let valor else { return "—" }
        return "\(valor)"
    }

    private func sinNada(_ valor: Double?) -> String {
        guard let valor else { return "—" }
        return String(format: "%.1f", valor)
    }
}
