import SwiftUI

/// El remo: lo que manda la máquina y lo que calcula la app con eso.
///
/// La máquina no informa distancia ni tiempo, así que la distancia la integra
/// la app a partir del ritmo instantáneo. Está separado en dos bloques para
/// que quede claro qué dato es medido y qué dato es calculado.
struct PantallaRemo: View {
    @ObservedObject var remo: LectorDeRemo

    var body: some View {
        Pantalla {
            Hero(numero: "\(Int(remo.distanciaCalculada))",
                 unidad: "metros",
                 estado: remo.estado,
                 señal: remo.sesionAbierta ? .conectado : .esperando,
                 alPie: alPie)

            if !remo.avisoDeRecuperacion.isEmpty {
                Bloque {
                    Celda {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 14))
                                .foregroundColor(Paleta.acento)
                            Text(remo.avisoDeRecuperacion)
                                .font(.system(size: 13))
                                .foregroundColor(Paleta.suave)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if remo.sesionAbierta {
                Bloque(titulo: "Sesión en curso") {
                    Accion(texto: "Terminar y guardar", simbolo: "checkmark.circle") {
                        remo.terminarSesion()
                    }
                    Linea()
                    Accion(texto: "Descartar", simbolo: "trash", destructiva: true) {
                        remo.descartarSesion()
                    }
                }
            }

            Bloque(titulo: "Lo que manda la máquina") {
                Fila("Ritmo por 500 m", enMinutos(remo.datos.ritmoPor500))
                Linea()
                Fila("Paladas por minuto", conUnDecimal(remo.datos.paladasPorMinuto))
                Linea()
                Fila("Watts", entero(remo.datos.watts))
                Linea()
                Fila("Paladas contadas", entero(remo.datos.paladasTotales))
            }

            Bloque(titulo: "Lo que calcula la app",
                   pie: "La máquina no manda distancia ni tiempo. Falta calibrar estos "
                      + "números contra el display del aparato.") {
                Fila("Tiempo remando", enMinutos(Int(remo.segundosRemando)))
                Linea()
                Fila("Tiempo total", enMinutos(Int(remo.segundosTotales)))
                Linea()
                Fila("Watts promedio", String(format: "%.0f", remo.wattsPromedioCalculado))
                Linea()
                Fila("Ritmo promedio", ritmoPromedio)
            }

            Bloque(titulo: "Sesiones guardadas",
                   pie: remo.sesiones.isEmpty ? nil
                      : "Mantené apretada una sesión para borrarla.") {
                if remo.sesiones.isEmpty {
                    Vacio("Todavía ninguna. Remá un rato y se guarda sola.")
                } else {
                    ForEach(enumerar(remo.sesiones)) { fila in
                        if fila.puesto > 0 { Linea() }
                        FilaDeSesion(sesion: fila.valor)
                            .contextMenu {
                                Button(role: .destructive) {
                                    remo.borrar(fila.valor)
                                } label: {
                                    Label("Borrar la sesión", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            if !remo.sesiones.isEmpty {
                Bloque(titulo: "Acumulado") {
                    Fila("Sesiones", "\(remo.sesiones.count)")
                    Linea()
                    Fila("Metros en total",
                         Kilos.grande(remo.sesiones.reduce(0) { $0 + $1.metros }) + " m")
                    Linea()
                    Fila("Tiempo remando",
                         enHoras(remo.sesiones.reduce(0) { $0 + $1.segundosRemando }))
                    Linea()
                    Fila("La más larga", masLarga)
                }
            }
        }
        .navigationTitle("Remo")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { remo.buscarDeNuevo() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    private var alPie: String? {
        let metros = Int(remo.distanciaCalculada)
        guard metros > 0 else { return nil }
        return "faltan \(max(0, 10_000 - metros)) para los 10 000"
    }

    private var masLarga: String {
        guard let s = remo.sesiones.max(by: { $0.metros < $1.metros }) else { return "—" }
        return String(format: "%.0f m · %@", s.metros, Fechas.corta(s.inicio))
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

    private func enHoras(_ segundos: Double) -> String {
        let horas = Int(segundos) / 3600
        let minutos = (Int(segundos) % 3600) / 60
        return horas > 0 ? "\(horas) h \(minutos) min" : "\(minutos) min"
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
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(Paleta.texto)
                Spacer()
                Text(sesion.inicio.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundColor(Paleta.suave)
            }
            Text(detalle)
                .font(.system(size: 12))
                .foregroundColor(Paleta.suave)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private var detalle: String {
        let minutos = Int(sesion.segundosRemando) / 60
        let segundos = Int(sesion.segundosRemando) % 60
        let ritmo = Int(sesion.ritmoPromedio)
        let ritmoTexto = ritmo > 0 ? String(format: "%d:%02d/500m", ritmo / 60, ritmo % 60) : "—"
        return "\(minutos):\(String(format: "%02d", segundos)) remando · \(ritmoTexto) · \(Int(sesion.wattsPromedio)) W · \(sesion.paladas) paladas"
    }
}
