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

                if !remo.avisoDeRecuperacion.isEmpty {
                    Section {
                        Label(remo.avisoDeRecuperacion, systemImage: "arrow.uturn.backward.circle")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Lo que manda la máquina") {
                    Fila("Ritmo por 500 m", enMinutos(remo.datos.ritmoPor500))
                    Fila("Paladas por minuto", conUnDecimal(remo.datos.paladasPorMinuto))
                    Fila("Watts", entero(remo.datos.watts))
                    Fila("Paladas contadas", entero(remo.datos.paladasTotales))
                }

                Section("Lo que calcula la app") {
                    Fila("Tiempo remando", enMinutos(Int(remo.segundosRemando)))
                    Fila("Tiempo total", enMinutos(Int(remo.segundosTotales)))
                    Fila("Watts promedio", String(format: "%.0f", remo.wattsPromedioCalculado))
                    Fila("Ritmo promedio", ritmoPromedio)
                }

                if remo.sesionAbierta {
                    Section("Sesión en curso") {
                        Button {
                            remo.terminarSesion()
                        } label: {
                            Label("Terminar y guardar", systemImage: "checkmark.circle")
                        }
                        Button(role: .destructive) {
                            remo.descartarSesion()
                        } label: {
                            Label("Descartar", systemImage: "trash")
                        }
                    }
                }

                Section("Sesiones guardadas") {
                    if remo.sesiones.isEmpty {
                        Text("Todavía ninguna. Remá un rato y se guarda sola.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(remo.sesiones) { sesion in
                            FilaDeSesion(sesion: sesion)
                        }
                        .onDelete { indices in
                            indices.map { remo.sesiones[$0] }.forEach(remo.borrar)
                        }
                    }
                }

            }
            .scrollContentBackground(.hidden)
            .background(Paleta.fondo)
            .navigationTitle("Remo")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { remo.buscarDeNuevo() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var distancia: some View {
        let metros = Int(remo.distanciaCalculada)
        return Hero(numero: "\(metros)",
                    unidad: "metros",
                    estado: remo.estado,
                    señal: remo.sesionAbierta ? .conectado : .esperando,
                    alPie: "faltan \(max(0, 10_000 - metros)) para los 10 000")
    }

    private var ritmoPromedio: String {
        guard remo.distanciaCalculada > 0 else { return "—" }
        let segundos = Int(remo.segundosRemando / (remo.distanciaCalculada / 500))
        return enMinutos(segundos)
    }

    private func enMinutos(_ segundos: Int?) -> String {
        guard let segundos, segundos > 0 else { return "—" }
        return String(format: "%d:%02d", segundos / 60, segundos % 60)
    }

    private func entero(_ valor: Int?) -> String {
        guard let valor else { return "—" }
        return "\(valor)"
    }

    private func conUnDecimal(_ valor: Double?) -> String {
        guard let valor else { return "—" }
        return String(format: "%.1f", valor)
    }
}

struct FilaDeSesion: View {
    let sesion: SesionDeRemo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(format: "%.0f m", sesion.metros))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Spacer()
                Text(sesion.inicio.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Text(detalle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var detalle: String {
        let minutos = Int(sesion.segundosRemando) / 60
        let segundos = Int(sesion.segundosRemando) % 60
        let ritmo = Int(sesion.ritmoPromedio)
        let ritmoTexto = ritmo > 0 ? String(format: "%d:%02d/500m", ritmo / 60, ritmo % 60) : "—"
        return "\(minutos):\(String(format: "%02d", segundos)) remando · \(ritmoTexto) · \(Int(sesion.wattsPromedio)) W · \(sesion.paladas) paladas"
    }
}
