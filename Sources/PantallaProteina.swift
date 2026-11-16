import SwiftUI

/// El contador de proteína: cuántos scoops y cuándo. A propósito simple.
struct PantallaProteina: View {
    @ObservedObject var diario: Diario

    @State private var otraCantidad = false
    @State private var corrigiendo: Consumo?

    var body: some View {
        Pantalla(titulo: "Proteína") {
            Hero(numero: Kilos.texto(diario.scoopsDeHoy),
                 unidad: diario.scoopsDeHoy == 1 ? "scoop hoy" : "scoops hoy",
                 estado: diario.scoopsDeHoy == 0 ? "Todavía ninguno" : "Anotado",
                 señal: diario.scoopsDeHoy == 0 ? .esperando : .conectado,
                 alPie: promedio)

            HStack(spacing: 12) {
                Boton(texto: "+ 1 scoop") { diario.anotarScoops(1) }
                Boton(texto: "+ ½") { diario.anotarScoops(0.5) }
            }

            Bloque {
                Accion(texto: "Anotar otra cantidad", simbolo: "plus.circle") {
                    otraCantidad = true
                }
            }

            Bloque(titulo: "Hoy",
                   pie: diario.consumoDeHoy.isEmpty ? nil
                      : "Tocá para corregir la cantidad. Mantené apretado para borrar.") {
                if diario.consumoDeHoy.isEmpty {
                    Vacio("Nada anotado todavía.")
                } else {
                    ForEach(enumerar(diario.consumoDeHoy)) { fila in
                        if fila.puesto > 0 { Linea() }
                        Button { corrigiendo = fila.valor } label: {
                            Celda {
                                HStack {
                                    Text(Kilos.texto(fila.valor.cantidad)
                                         + (fila.valor.cantidad == 1 ? " scoop" : " scoops"))
                                        .font(.system(size: 15, weight: .medium))
                                        .monospacedDigit()
                                        .foregroundColor(Paleta.texto)
                                    Spacer()
                                    Text(fila.valor.instante.formatted(date: .omitted,
                                                                       time: .shortened))
                                        .font(.system(size: 12))
                                        .foregroundColor(Paleta.suave)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                diario.borrar(fila.valor)
                            } label: {
                                Label("Borrar", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Bloque(titulo: "Días anteriores") {
                let dias = diario.consumoPorDia().filter {
                    !Calendar.current.isDateInToday($0.dia)
                }
                if dias.isEmpty {
                    Vacio("Sin historial todavía.")
                } else {
                    ForEach(enumerar(dias)) { fila in
                        if fila.puesto > 0 { Linea() }
                        Fila(Fechas.relativa(fila.valor.dia).capitalizedPrimera,
                             Kilos.texto(fila.valor.total))
                    }
                }
            }
        }
        .sheet(isPresented: $otraCantidad) {
            EditorDeScoops { cuantos in diario.anotarScoops(cuantos) }
        }
        .sheet(item: $corrigiendo) { c in
            EditorDeScoops(cantidadInicial: c.cantidad) { cuantos in
                diario.reemplazar(c, cantidad: cuantos)
            }
        }
    }

    private var promedio: String? {
        let dias = diario.consumoPorDia(ultimos: 7)
        guard dias.count >= 2 else { return nil }
        let total = dias.reduce(0.0) { $0 + $1.total }
        return String(format: "%.1f por día en los últimos %d días con registro",
                      total / Double(dias.count), dias.count)
    }
}

/// Un botón ancho con el color de la marca.
struct Boton: View {
    let texto: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Text(texto)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Paleta.acento))
        }
        .buttonStyle(.plain)
    }
}
