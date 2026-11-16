import SwiftUI

/// Dónde se cargan los objetivos. Todos opcionales: el que se deja vacío no
/// aparece en ninguna otra pantalla.
struct PantallaObjetivos: View {
    @ObservedObject var metas: Metas

    @State private var peso = ""
    @State private var metros = ""
    @State private var dias = ""
    @State private var scoops = ""
    @State private var gastos = ""
    @State private var cargado = false
    @State private var guardado = false

    var body: some View {
        Pantalla(titulo: "Objetivos",
                 bajada: "Dejá vacío el que no quieras usar") {
            Campo(titulo: "Peso al que apuntás", unidad: "kg",
                  ejemplo: "78", texto: $peso,
                  ayuda: "Con esto, la pantalla de Peso muestra cuánto falta y "
                       + "en qué fecha llegarías si la tendencia se mantiene.")

            Campo(titulo: "Metros de remo por semana", unidad: "m",
                  ejemplo: "6000", texto: $metros,
                  ayuda: "Se ve como barra de avance en La semana y en el inicio.")

            Campo(titulo: "Días de entrenamiento por semana", unidad: "días",
                  ejemplo: "4", texto: $dias,
                  ayuda: "Cuenta los días con remo o con pesas.")

            Campo(titulo: "Scoops de proteína por día", unidad: "scoops",
                  ejemplo: "2", texto: $scoops,
                  ayuda: "Se compara contra el promedio de los últimos siete días.")

            Campo(titulo: "Tope de gastos por mes", unidad: "$",
                  ejemplo: "60000", texto: $gastos,
                  ayuda: "Acá pasarse no es un logro: la barra se pone roja.")

            Boton(texto: guardado ? "Guardado" : "Guardar") {
                metas.guardar(armados)
                guardado = true
            }

            Bloque {
                Celda {
                    Text("Los objetivos no cambian nada de lo que la app guarda. "
                         + "Solo cambian cómo se muestran los números: en vez de "
                         + "decir cuánto hubo, dicen cuánto falta.")
                        .font(.system(size: 13))
                        .foregroundColor(Paleta.suave)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear(perform: preparar)
        .onChange(of: peso) { _ in guardado = false }
        .onChange(of: metros) { _ in guardado = false }
        .onChange(of: dias) { _ in guardado = false }
        .onChange(of: scoops) { _ in guardado = false }
        .onChange(of: gastos) { _ in guardado = false }
    }

    private var armados: Objetivos {
        Objetivos(peso: leer(peso),
                  metrosPorSemana: leer(metros),
                  diasPorSemana: leer(dias).map { max(0, min(7, Int($0))) },
                  scoopsPorDia: leer(scoops),
                  topeDeGastos: leer(gastos))
    }

    private func leer(_ texto: String) -> Double? {
        let limpio = texto.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty, let valor = Double(limpio), valor > 0 else { return nil }
        return valor
    }

    private func preparar() {
        guard !cargado else { return }
        cargado = true
        let o = metas.objetivos
        peso = o.peso.map { escribir($0) } ?? ""
        metros = o.metrosPorSemana.map { escribir($0) } ?? ""
        dias = o.diasPorSemana.map { "\($0)" } ?? ""
        scoops = o.scoopsPorDia.map { escribir($0) } ?? ""
        gastos = o.topeDeGastos.map { escribir($0) } ?? ""
    }

    private func escribir(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%g", v)
    }
}

/// Un objetivo: su nombre, el casillero del número y una línea de para qué
/// sirve.
private struct Campo: View {
    let titulo: String
    let unidad: String
    let ejemplo: String
    @Binding var texto: String
    let ayuda: String

    var body: some View {
        Bloque(titulo: titulo, pie: ayuda) {
            HStack(spacing: 10) {
                TextField(ejemplo, text: $texto)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Paleta.texto)
                Text(unidad)
                    .font(.system(size: 15))
                    .foregroundColor(Paleta.suave)
                if !texto.isEmpty {
                    Button { texto = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(Paleta.suave)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
    }
}
