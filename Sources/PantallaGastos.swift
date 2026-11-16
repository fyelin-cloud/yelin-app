import SwiftUI

/// Gastos: anotar rápido y ver en qué se va la plata este mes.
struct PantallaGastos: View {
    @ObservedObject var diario: Diario
    @State private var anotando = false

    var body: some View {
        Pantalla {
            Hero(numero: Plata.corto(diario.totalDelMes()),
                 unidad: "este mes",
                 estado: comparacion,
                 señal: .esperando,
                 alPie: "\(diario.gastosDelMes().count) gastos anotados")

            Boton(texto: "Anotar un gasto") { anotando = true }

            Bloque(titulo: "Por categoría") {
                let filas = diario.porCategoria()
                if filas.isEmpty {
                    Vacio("Todavía no hay gastos este mes.")
                } else {
                    ForEach(enumerar(filas)) { fila in
                        if fila.puesto > 0 { Linea() }
                        CategoriaDeGasto(fila: fila.valor,
                                         techo: filas.map { $0.esteMes }.max() ?? 1)
                    }
                }
            }

            Bloque(titulo: "Este mes",
                   pie: diario.gastosDelMes().isEmpty ? nil
                      : "Mantené apretado un gasto para borrarlo.") {
                let delMes = diario.gastosDelMes()
                if delMes.isEmpty {
                    Vacio("Nada anotado todavía.")
                } else {
                    ForEach(enumerar(delMes)) { fila in
                        if fila.puesto > 0 { Linea() }
                        FilaDeGasto(gasto: fila.valor)
                            .contextMenu {
                                Button(role: .destructive) {
                                    diario.borrar(fila.valor)
                                } label: {
                                    Label("Borrar el gasto", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Gastos")
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
}

/// Una categoría con su barrita proporcional, para ver de un saque en qué se
/// va la plata sin tener que comparar números.
private struct CategoriaDeGasto: View {
    let fila: (categoria: String, esteMes: Double, mesPasado: Double)
    let techo: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(fila.categoria)
                    .font(.system(size: 15))
                    .foregroundColor(Paleta.texto)
                Spacer()
                Text(Plata.corto(fila.esteMes))
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(Paleta.texto)
                Text(contraMesPasado)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundColor(Paleta.suave)
                    .frame(width: 58, alignment: .trailing)
            }
            GeometryReader { espacio in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Paleta.borde)
                        .frame(height: 4)
                    Capsule()
                        .fill(Paleta.acento)
                        .frame(width: max(3, espacio.size.width * proporcion), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var proporcion: Double {
        guard techo > 0 else { return 0 }
        return min(1, fila.esteMes / techo)
    }

    private var contraMesPasado: String {
        guard fila.mesPasado > 0 else { return "nuevo" }
        let cambio = (fila.esteMes - fila.mesPasado) / fila.mesPasado * 100
        return String(format: "%+.0f%%", cambio)
    }
}

struct FilaDeGasto: View {
    let gasto: Gasto

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(gasto.categoria)
                    .font(.system(size: 15))
                    .foregroundColor(Paleta.texto)
                if !gasto.detalle.isEmpty {
                    Text(gasto.detalle)
                        .font(.system(size: 12))
                        .foregroundColor(Paleta.suave)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Plata.corto(gasto.monto))
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(Paleta.texto)
                Text(Fechas.corta(gasto.instante))
                    .font(.system(size: 11))
                    .foregroundColor(Paleta.suave)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
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
        NavigationStack {
            Pantalla(titulo: "Gasto nuevo") {
                Bloque(titulo: "Cuánto") {
                    HStack(spacing: 8) {
                        Text("$")
                            .font(.system(size: 30, weight: .medium, design: .rounded))
                            .foregroundColor(Paleta.suave)
                        TextField("0", text: $monto)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(Paleta.texto)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Bloque(titulo: "En qué") {
                    ForEach(enumerar(categorias)) { fila in
                        if fila.puesto > 0 { Linea() }
                        Button { categoria = fila.valor } label: {
                            HStack {
                                Text(fila.valor)
                                    .font(.system(size: 15))
                                    .foregroundColor(Paleta.texto)
                                Spacer()
                                if categoria == fila.valor {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Paleta.acento)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Bloque(titulo: "Detalle", pie: "Opcional.") {
                    TextField("Nada en particular", text: $detalle)
                        .font(.system(size: 15))
                        .foregroundColor(Paleta.texto)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

                Boton(texto: "Guardar") {
                    if let valor = montoValido { guardar(valor, categoria, detalle) }
                    cerrar()
                }
                .opacity(puedeGuardar ? 1 : 0.4)
                .disabled(!puedeGuardar)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
            .onAppear { if categoria.isEmpty { categoria = categorias.first ?? "Otros" } }
        }
    }

    private var puedeGuardar: Bool {
        (montoValido ?? 0) > 0 && !categoria.isEmpty
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
