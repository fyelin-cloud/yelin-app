import SwiftUI

/// El contador de proteína: cuántos scoops y cuándo. A propósito simple.
struct PantallaProteina: View {
    @ObservedObject var diario: Diario

    var body: some View {
        List {
            Section {
                Hero(numero: formato(diario.scoopsDeHoy),
                     unidad: diario.scoopsDeHoy == 1 ? "scoop hoy" : "scoops hoy",
                     estado: diario.scoopsDeHoy == 0 ? "Todavía ninguno" : "Anotado",
                     señal: diario.scoopsDeHoy == 0 ? .esperando : .conectado)
            }

            Section {
                HStack(spacing: 12) {
                    Boton(texto: "+ 1 scoop") { diario.anotarScoops(1) }
                    Boton(texto: "+ ½") { diario.anotarScoops(0.5) }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            Section("Hoy") {
                if diario.consumoDeHoy.isEmpty {
                    Text("Nada anotado todavía.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(diario.consumoDeHoy) { c in
                        HStack {
                            Text(formato(c.cantidad) + (c.cantidad == 1 ? " scoop" : " scoops"))
                                .monospacedDigit()
                            Spacer()
                            Text(c.instante.formatted(date: .omitted, time: .shortened))
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { indices in
                        indices.map { diario.consumoDeHoy[$0] }.forEach(diario.borrar)
                    }
                }
            }

            Section("Días anteriores") {
                let dias = diario.consumoPorDia().filter {
                    !Calendar.current.isDateInToday($0.dia)
                }
                if dias.isEmpty {
                    Text("Sin historial todavía.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(dias, id: \.dia) { fila in
                        HStack {
                            Text(fila.dia.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(formato(fila.total))
                                .fontWeight(.medium)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Paleta.fondo)
        .navigationTitle("Proteína")
        .toolbar { EditButton() }
    }

    private func formato(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

/// Un botón ancho con el color de la marca.
struct Boton: View {
    let texto: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Text(texto)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Paleta.acento))
        }
        .buttonStyle(.plain)
    }
}
