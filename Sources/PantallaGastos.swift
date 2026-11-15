import SwiftUI

/// Gastos: anotar rápido y ver en qué se va la plata este mes.
struct PantallaGastos: View {
    @ObservedObject var diario: Diario
    @State private var anotando = false

    var body: some View {
        List {
            Section {
                Hero(numero: Plata.corto(diario.totalDelMes()),
                     unidad: "este mes",
                     estado: comparacion,
                     señal: .esperando)
            }

            Section {
                Boton(texto: "Anotar un gasto") { anotando = true }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            Section("Por categoría") {
                let filas = diario.porCategoria()
                if filas.isEmpty {
                    Text("Todavía no hay gastos este mes.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filas, id: \.categoria) { fila in
                        HStack {
                            Text(fila.categoria)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Plata.corto(fila.esteMes))
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                                Text(contraMesPasado(fila.esteMes, fila.mesPasado))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Este mes") {
                let delMes = diario.gastosDelMes()
                if delMes.isEmpty {
                    Text("Nada anotado todavía.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(delMes) { gasto in
                        FilaDeGasto(gasto: gasto)
                    }
                    .onDelete { indices in
                        indices.map { delMes[$0] }.forEach(diario.borrar)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Paleta.fondo)
        .navigationTitle("Gastos")
        .toolbar { EditButton() }
        .sheet(isPresented: $anotando) {
            NuevoGasto(categorias: diario.categorias) { monto, categoria, detalle in
                diario.anotarGasto(monto: monto, categoria: categoria, detalle: detalle)
            }
        }
    }

    private var comparacion: String {
        let pasado = diario.totalDelMes(corrido: 1)
        guard pasado > 0 else { return "Sin mes anterior para comparar" }
        let diferencia = diario.totalDelMes() - pasado
        let signo = diferencia >= 0 ? "+" : "−"
        return "\(signo)\(Plata.corto(abs(diferencia))) contra el mes pasado"
    }

    private func contraMesPasado(_ ahora: Double, _ antes: Double) -> String {
        guard antes > 0 else { return "nuevo" }
        let cambio = (ahora - antes) / antes * 100
        return String(format: "%+.0f%% vs mes pasado", cambio)
    }
}

struct FilaDeGasto: View {
    let gasto: Gasto

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(gasto.categoria)
                    .font(.system(size: 16))
                if !gasto.detalle.isEmpty {
                    Text(gasto.detalle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Plata.corto(gasto.monto))
                    .fontWeight(.medium)
                    .monospacedDigit()
                Text(gasto.instante.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct NuevoGasto: View {
    let categorias: [String]
    let guardar: (Double, String, String) -> Void

    @State private var monto = ""
    @State private var categoria = ""
    @State private var detalle = ""
    @Environment(\.dismiss) private var cerrar

    private var montoValido: Double? {
        Double(monto.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Cuánto") {
                    TextField("0", text: $monto)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                Section("En qué") {
                    Picker("Categoría", selection: $categoria) {
                        ForEach(categorias, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Detalle (opcional)") {
                    TextField("Nada en particular", text: $detalle)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Paleta.fondo)
            .navigationTitle("Gasto nuevo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if let valor = montoValido {
                            guardar(valor, categoria, detalle)
                        }
                        cerrar()
                    }
                    .disabled((montoValido ?? 0) <= 0 || categoria.isEmpty)
                }
            }
            .onAppear { if categoria.isEmpty { categoria = categorias.first ?? "Otros" } }
        }
        .navigationViewStyle(.stack)
    }
}

/// Montos en pesos, cortos para que entren en una fila.
enum Plata {
    static func corto(_ monto: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.numberStyle = .decimal
        f.maximumFractionDigits = monto >= 1000 ? 0 : 2
        let numero = f.string(from: NSNumber(value: monto)) ?? "0"
        return "$" + numero
    }
}
