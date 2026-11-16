import SwiftUI

/// Las ventanitas para corregir algo ya cargado o meterlo a mano.
///
/// **Por qué existen**: hasta ahora lo único que se podía hacer con un dato
/// mal cargado era borrarlo y volver a empezar, y no había forma de cargar una
/// pesada vieja con su fecha.

// MARK: - Scoops

struct EditorDeScoops: View {
    var cantidadInicial: Double = 1
    let guardar: (Double) -> Void

    @State private var cantidad: Double = 1
    @State private var cargado = false
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            Pantalla(titulo: "Proteína", bajada: "Cuántos scoops") {
                Bloque {
                    Contador(valor: cantidad,
                             texto: Kilos.texto(cantidad),
                             paso: "½",
                             menos: { cantidad = max(0.5, cantidad - 0.5) },
                             mas: { cantidad = min(20, cantidad + 0.5) })
                }
                Boton(texto: "Guardar") {
                    guardar(cantidad)
                    cerrar()
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
            .onAppear {
                if !cargado { cantidad = cantidadInicial; cargado = true }
            }
        }
    }
}

// MARK: - Series de pesas

struct EditorDeSerie: View {
    let ejercicio: String
    var repeticionesIniciales: Int = 10
    var kilosIniciales: Double = 20
    let guardar: (Int, Double) -> Void

    @State private var repeticiones = 10
    @State private var kilos: Double = 20
    @State private var cargado = false
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            Pantalla(titulo: ejercicio,
                     bajada: "Volumen: \(Kilos.grande(Double(repeticiones) * kilos)) kg") {
                Bloque(titulo: "Repeticiones") {
                    Contador(valor: Double(repeticiones), texto: "\(repeticiones)", paso: "1",
                             menos: { repeticiones = max(1, repeticiones - 1) },
                             mas: { repeticiones = min(300, repeticiones + 1) })
                }
                Bloque(titulo: "Kilos") {
                    Contador(valor: kilos, texto: Kilos.texto(kilos), paso: "2,5",
                             menos: { kilos = max(0, kilos - 2.5) },
                             mas: { kilos = min(500, kilos + 2.5) })
                }
                Boton(texto: "Guardar") {
                    guardar(repeticiones, kilos)
                    cerrar()
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
            .onAppear {
                guard !cargado else { return }
                repeticiones = repeticionesIniciales
                kilos = kilosIniciales
                cargado = true
            }
        }
    }
}

// MARK: - Pesadas

/// Cargar o corregir una pesada, con su fecha y hora.
///
/// Acá sí se usa el selector de fecha del sistema: elegir un día de hace tres
/// meses con botones de más y menos sería peor, y no es un menú.
struct EditorDePesada: View {
    var pesada: Pesada?
    let guardar: (Double, Date) -> Void

    @State private var kilos = ""
    @State private var cuando = Date()
    @State private var cargado = false
    @Environment(\.dismiss) private var cerrar

    private var valor: Double? {
        Double(kilos.replacingOccurrences(of: ",", with: "."))
    }

    private var sirve: Bool {
        guard let valor else { return false }
        return valor > 20 && valor < 400
    }

    var body: some View {
        NavigationStack {
            Pantalla(titulo: pesada == nil ? "Pesada a mano" : "Corregir la pesada",
                     bajada: pesada == nil
                           ? "Para meter una de antes de tener la app" : nil) {
                Bloque(titulo: "Cuántos kilos") {
                    HStack(spacing: 10) {
                        TextField("81,40", text: $kilos)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(Paleta.texto)
                        Text("kg")
                            .font(.system(size: 18))
                            .foregroundColor(Paleta.suave)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Bloque(titulo: "Cuándo") {
                    Celda {
                        DatePicker("", selection: $cuando,
                                   in: ...Date(),
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .tint(Paleta.acento)
                            .environment(\.locale, Locale(identifier: "es_AR"))
                    }
                }

                Boton(texto: "Guardar") {
                    if let valor { guardar(valor, cuando) }
                    cerrar()
                }
                .opacity(sirve ? 1 : 0.4)
                .disabled(!sirve)

                Bloque {
                    Celda {
                        Text("Las pesadas cargadas a mano entran al historial y a la "
                             + "tendencia igual que las que manda la balanza.")
                            .font(.system(size: 13))
                            .foregroundColor(Paleta.suave)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
            .onAppear {
                guard !cargado else { return }
                if let pesada {
                    kilos = String(format: "%.2f", pesada.kg).replacingOccurrences(of: ".", with: ",")
                    cuando = pesada.instante
                }
                cargado = true
            }
        }
    }
}
