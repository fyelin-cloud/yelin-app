import SwiftUI
import Charts

/// El historial de peso: gráfico, promedio móvil y tendencia.
struct PantallaPeso: View {
    let pesadas: [Pesada]
    @ObservedObject var metas: Metas

    private let puntos: [PuntoDePeso]
    private let promedio: [PuntoDePeso]
    private let sospechosas: Set<UUID>

    init(pesadas: [Pesada], metas: Metas) {
        self.pesadas = pesadas
        self.metas = metas
        let porDia = Analisis.porDia(pesadas)
        let media = Analisis.promedioMovil(porDia)
        self.puntos = porDia
        self.promedio = media
        self.sospechosas = Analisis.sospechosas(porDia, promedio: media)
    }

    var body: some View {
        Pantalla(titulo: "Peso", bajada: bajada) {
            if puntos.count < 2 {
                Bloque {
                    Vacio("Con una sola pesada no hay nada que graficar. Pesate unos "
                          + "días y acá va a aparecer la tendencia.")
                }
            } else {
                Bloque(titulo: "Últimos días",
                       pie: "Los puntos son cada día; la línea es el promedio de 7 días, "
                          + "que es lo que conviene mirar.") {
                    grafico
                        .frame(height: 230)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                }
            }

            Bloque(titulo: "Números") {
                Filas(numeros)
            }

            if !sospechosas.isEmpty {
                Bloque(titulo: "Para mirar",
                       pie: "Se alejan más de 2 kg del promedio. Puede ser una pesada "
                          + "mal tomada.") {
                    ForEach(enumerar(puntos.filter { sospechosas.contains($0.id) })) { fila in
                        if fila.puesto > 0 { Linea() }
                        Fila(Fechas.conAnio(fila.valor.fecha),
                             String(format: "%.2f kg", fila.valor.kg))
                    }
                }
            }
        }
    }

    private var numeros: [(String, String)] {
        var lista: [(String, String)] = []
        if let ultimo = puntos.last {
            lista.append(("Último", String(format: "%.2f kg", ultimo.kg)))
        }
        if let media = promedio.last {
            lista.append(("Promedio de 7 días", String(format: "%.2f kg", media.kg)))
        }
        lista.append(("Cambio en 7 días", conSigno(Analisis.cambio(puntos, dias: 7))))
        lista.append(("Cambio en 30 días", conSigno(Analisis.cambio(puntos, dias: 30))))
        lista.append(("Tendencia", tendencia))
        lista.append(("Días con registro", "\(puntos.count)"))
        lista.append(("Pesadas en total", "\(pesadas.count)"))
        if let objetivo = metas.objetivos.peso {
            lista.append(("Objetivo", String(format: "%.1f kg", objetivo)))
            if let falta = metas.objetivos.faltaParaElPeso(desde: puntos.last?.kg) {
                lista.append((falta < 0 ? "Falta bajar" : "Falta subir",
                              String(format: "%.2f kg", abs(falta))))
            }
            if let cuando = metas.objetivos.fechaEstimada(
                desde: puntos.last?.kg,
                porSemana: Analisis.tendenciaPorSemana(puntos)) {
                lista.append(("Llegarías el", Fechas.conAnio(cuando)))
            }
        }
        return lista
    }

    private var bajada: String {
        guard puntos.count >= 2 else { return "Todavía sin tendencia" }
        guard let porSemana = Analisis.tendenciaPorSemana(puntos) else {
            return "\(puntos.count) días con registro"
        }
        if abs(porSemana) < 0.05 { return "Estable en las últimas semanas" }
        return String(format: "%@ %.2f kg por semana",
                      porSemana > 0 ? "Subiendo" : "Bajando", abs(porSemana))
    }

    private var grafico: some View {
        Chart {
            ForEach(puntos) { punto in
                PointMark(
                    x: .value("Día", punto.fecha),
                    y: .value("Kilos", punto.kg)
                )
                .foregroundStyle(Paleta.suave.opacity(0.75))
                .symbolSize(32)
            }
            ForEach(promedio) { punto in
                LineMark(
                    x: .value("Día", punto.fecha),
                    y: .value("Promedio", punto.kg)
                )
                .foregroundStyle(Paleta.acento)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
        .chartYScale(domain: Analisis.rangoVertical(puntos))
        .chartYAxis {
            AxisMarks(position: .leading) { valor in
                AxisGridLine().foregroundStyle(Paleta.borde)
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(Paleta.suave)
            }
        }
        .chartXAxis {
            AxisMarks { valor in
                AxisGridLine().foregroundStyle(Paleta.borde.opacity(0.5))
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    .font(.system(size: 10))
                    .foregroundStyle(Paleta.suave)
            }
        }
    }

    private var tendencia: String {
        guard let porSemana = Analisis.tendenciaPorSemana(puntos) else {
            return "faltan días"
        }
        return String(format: "%+.2f kg por semana", porSemana)
    }

    private func conSigno(_ valor: Double?) -> String {
        guard let valor else { return "—" }
        return String(format: "%+.2f kg", valor)
    }
}
