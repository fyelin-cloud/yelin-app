import SwiftUI

/// Las dos cuentas que se hacen al entrenar: cuánto podría levantar una vez,
/// y qué discos poner para llegar a un peso.
struct PantallaCalculadoras: View {
    @ObservedObject var pesas: Pesas
    @ObservedObject var fierros: Fierros

    @State private var peso = ""
    @State private var repeticiones = 5
    @State private var eligiendo = false
    @State private var ejercicio = ""

    private var kilos: Double? {
        Double(peso.replacingOccurrences(of: ",", with: "."))
    }

    private var maxima: Double? {
        guard let kilos else { return nil }
        return Calculo.maximaEstimada(peso: kilos, repeticiones: repeticiones)
    }

    var body: some View {
        Pantalla(titulo: "Calculadoras") {
            Bloque(titulo: "Repetición máxima",
                   pie: "Es una estimación con la fórmula de Epley, no una "
                      + "medición. Sirve para elegir cargas, no para anotar un "
                      + "récord.") {
                HStack(spacing: 10) {
                    TextField("40", text: $peso)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Paleta.texto)
                    Text("kg")
                        .font(.system(size: 16))
                        .foregroundColor(Paleta.suave)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                Linea()
                Contador(valor: Double(repeticiones),
                         texto: "\(repeticiones)",
                         paso: "1",
                         menos: { repeticiones = max(1, repeticiones - 1) },
                         mas: { repeticiones = min(30, repeticiones + 1) })
                if !pesas.ejerciciosConHistorial().isEmpty {
                    Linea()
                    Elegido(rotulo: "Traer de un ejercicio",
                            valor: ejercicio.isEmpty ? "Elegir" : ejercicio,
                            vacio: ejercicio.isEmpty) { eligiendo = true }
                }
            }

            if let maxima {
                Bloque(titulo: "Tu máximo estimado") {
                    Celda {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(format: "%.1f kg", maxima))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(Paleta.acento)
                            Text(Calculo.confianza(repeticiones))
                                .font(.system(size: 12))
                                .foregroundColor(Paleta.suave)
                        }
                    }
                }

                Bloque(titulo: "Con cuánto entrenar",
                       pie: "Los porcentajes de ese máximo, redondeados a 0,5 kg.") {
                    Filas(Calculo.porcentajes.map { porcentaje in
                        ("\(porcentaje) %",
                         String(format: "%.1f kg", redondear(maxima * Double(porcentaje) / 100)))
                    })
                }
            } else {
                Bloque { Vacio("Poné cuántos kilos levantaste y cuántas veces.") }
            }

            Bloque {
                Navega(texto: "Calculadora de discos", simbolo: "circle.circle") {
                    PantallaDiscos(fierros: fierros)
                }
            }
        }
        .sheet(isPresented: $eligiendo) {
            Eleccion(titulo: "Traer de un ejercicio",
                     opciones: pesas.ejerciciosConHistorial(),
                     elegida: ejercicio) { elegido in
                ejercicio = elegido
                if let record = pesas.record(de: elegido) {
                    peso = String(format: "%g", record.kilos)
                    repeticiones = record.repeticiones
                }
            }
        }
    }

    /// Los discos más chicos suelen ser de 1,25 kg, así que de a medio kilo
    /// alcanza y no marea con decimales imposibles de armar.
    private func redondear(_ v: Double) -> Double {
        (v * 2).rounded() / 2
    }
}

// MARK: - Discos

struct PantallaDiscos: View {
    @ObservedObject var fierros: Fierros

    @State private var objetivo = ""
    @State private var nuevoDisco = ""
    @State private var cuantos = 2

    private var pedido: Double? {
        Double(objetivo.replacingOccurrences(of: ",", with: "."))
    }

    private var armado: Armado? {
        guard let pedido, pedido > 0 else { return nil }
        return Calculo.armar(pedido, con: fierros.equipo)
    }

    var body: some View {
        Pantalla(titulo: "Discos",
                 bajada: "Qué poner de cada lado para llegar a un peso") {
            Bloque(titulo: "Cuánto querés levantar") {
                HStack(spacing: 10) {
                    TextField("60", text: $objetivo)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Paleta.texto)
                    Text("kg en total")
                        .font(.system(size: 15))
                        .foregroundColor(Paleta.suave)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }

            if let armado {
                Bloque(titulo: "De cada lado",
                       pie: armado.exacto ? nil
                          : String(format: "Con lo que tenés no llega justo: queda "
                                   + "en %.1f kg, %.1f menos de lo que pediste.",
                                   armado.total, armado.pedido - armado.total)) {
                    Celda {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(armado.texto)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundColor(Paleta.acento)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(String(format: "Barra de %g kg · total %.1f kg",
                                        fierros.equipo.barra, armado.total))
                                .font(.system(size: 13))
                                .foregroundColor(Paleta.suave)
                        }
                    }
                }
            }

            Bloque(titulo: "La barra") {
                Contador(valor: fierros.equipo.barra,
                         texto: String(format: "%g", fierros.equipo.barra),
                         paso: "0,5",
                         menos: { fierros.cambiarBarra(fierros.equipo.barra - 0.5) },
                         mas: { fierros.cambiarBarra(fierros.equipo.barra + 0.5) })
            }

            Bloque(titulo: "Agregar discos",
                   pie: "Poné cuántos kilos pesa cada uno y cuántos tenés en "
                      + "total, contando los dos lados.") {
                HStack(spacing: 10) {
                    TextField("Kilos", text: $nuevoDisco)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 17))
                        .foregroundColor(Paleta.texto)
                    Text("×")
                        .font(.system(size: 15))
                        .foregroundColor(Paleta.suave)
                    Button { cuantos = max(2, cuantos - 2) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Paleta.acento)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Paleta.acento.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    Text("\(cuantos)")
                        .font(.system(size: 17, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(Paleta.texto)
                        .frame(width: 26)
                    Button { cuantos = min(20, cuantos + 2) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Paleta.acento)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Paleta.acento.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    Button(action: agregar) {
                        Text("Sumar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Paleta.acento))
                    }
                    .buttonStyle(.plain)
                    .opacity(Double(nuevoDisco.replacingOccurrences(of: ",", with: ".")) == nil ? 0.4 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Bloque(titulo: "Lo que tenés",
                   pie: fierros.equipo.discos.isEmpty ? nil
                      : String(format: "Con todo puesto llegás a %.1f kg. Mantené "
                               + "apretado un disco para sacarlo.", fierros.equipo.maximo)) {
                if fierros.equipo.discos.isEmpty {
                    Vacio("No hay discos cargados.")
                } else {
                    ForEach(enumerar(fierros.equipo.discos)) { fila in
                        if fila.puesto > 0 { Linea() }
                        Celda {
                            HStack {
                                Text(String(format: "%g kg", fila.valor.kilos))
                                    .font(.system(size: 16, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundColor(Paleta.texto)
                                Spacer()
                                Text("\(fila.valor.cuantos) discos · \(fila.valor.pares) por lado")
                                    .font(.system(size: 13))
                                    .foregroundColor(Paleta.suave)
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button(role: .destructive) {
                                fierros.quitarDisco(fila.valor)
                            } label: {
                                Label("Sacar estos discos", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func agregar() {
        guard let kilos = Double(nuevoDisco.replacingOccurrences(of: ",", with: ".")) else { return }
        fierros.agregarDisco(kilos: kilos, cuantos: cuantos)
        nuevoDisco = ""
    }
}
