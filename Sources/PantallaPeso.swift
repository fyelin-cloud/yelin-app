import SwiftUI
import Charts

/// El historial de peso: gráfico, promedio móvil y tendencia.
struct PantallaPeso: View {
    let pesadas: [Pesada]

    private let puntos: [PuntoDePeso]
    private let promedio: [PuntoDePeso]
    private let sospechosas: Set<UUID>

    init(pesadas: [Pesada]) {
        self.pesadas = pesadas
        let porDia = Analisis.porDia(pesadas)
        let media = Analisis.promedioMovil(porDia)
        self.puntos = porDia
        self.promedio = media
        self.sospechosas = Analisis.sospechosas(porDia, promedio: media)
    }

    var body: some View {
        List {
            if puntos.count < 2 {
                Section {
                    Text("Con una sola pesada no hay nada que graficar. Pesate unos días y acá va a aparecer la tendencia.")
                        .foregroundColor(.secondary)
                }
            } else {
                Section("Últimos días") {
                    grafico
                        .frame(height: 240)
                        .padding(.vertical, 8)
                }
            }

            Section("Números") {
                if let ultimo = puntos.last {
                    Fila("Último", String(format: "%.2f kg", ultimo.kg))
                }
                if let media = promedio.last {
                    Fila("Promedio de 7 días", String(format: "%.2f kg", media.kg))
                }
                Fila("Cambio en 7 días", conSigno(Analisis.cambio(puntos, dias: 7)))
                Fila("Cambio en 30 días", conSigno(Analisis.cambio(puntos, dias: 30)))
                Fila("Tendencia", tendencia)
                Fila("Días con registro", "\(puntos.count)")
                Fila("Pesadas en total", "\(pesadas.count)")
            }

            if !sospechosas.isEmpty {
                Section("Para mirar") {
                    Text("Hay \(sospechosas.count) día(s) que se alejan más de 2 kg del promedio. Puede ser una pesada mal tomada.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    ForEach(puntos.filter { sospechosas.contains($0.id) }) { punto in
                        HStack {
                            Text(String(format: "%.2f kg", punto.kg)).monospacedDigit()
                            Spacer()
                            Text(punto.fecha.formatted(date: .abbreviated, time: .omitted))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
            .background(Paleta.fondo)
            .navigationTitle("Peso")
    }

    private var grafico: some View {
        Chart {
            ForEach(puntos) { punto in
                PointMark(
                    x: .value("Día", punto.fecha),
                    y: .value("Kilos", punto.kg)
                )
                .foregroundStyle(Paleta.suave)
                .symbolSize(40)
            }
            ForEach(promedio) { punto in
                LineMark(
                    x: .value("Día", punto.fecha),
                    y: .value("Promedio", punto.kg)
                )
                .foregroundStyle(Paleta.acento)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
        }
        .chartYScale(domain: Analisis.rangoVertical(puntos))
        .chartYAxis {
            AxisMarks(position: .leading)
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
