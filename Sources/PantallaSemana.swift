import SwiftUI

/// La semana: todo cruzado y comparado contra los siete días anteriores.
struct PantallaSemana: View {
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var remo: LectorDeRemo
    @ObservedObject var diario: Diario
    @ObservedObject var pesas: Pesas

    @Environment(\.horizontalSizeClass) private var anchoDePantalla

    private var semana: Semana {
        Semana.armar(pesadas: balanza.pesadas,
                     sesiones: remo.sesiones,
                     consumo: diario.consumo,
                     gastos: diario.gastos,
                     series: pesas.series)
    }

    private var columnas: [GridItem] {
        let cuantas = anchoDePantalla == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: cuantas)
    }

    var body: some View {
        let s = semana
        return Pantalla(titulo: "La semana", bajada: periodo(s)) {
            LazyVGrid(columns: columnas, spacing: 12) {
                Dato(valor: pesoTexto(s),
                     rotulo: "Peso",
                     detalle: pesoDetalle(s),
                     color: s.pesoPromedio.hayConQueComparar && s.pesoPromedio.ahora > 0
                          ? Tono.segun(s.pesoPromedio.cambio, alReves: true) : Paleta.texto)

                Dato(valor: s.metros.ahora > 0 ? Kilos.grande(s.metros.ahora) : "—",
                     rotulo: "Metros remados",
                     detalle: comparar(s.metros, unidad: "m"),
                     color: s.metros.ahora > 0 ? Paleta.texto : Paleta.suave)

                Dato(valor: s.volumenDePesas.ahora > 0 ? Kilos.grande(s.volumenDePesas.ahora) : "—",
                     rotulo: "Volumen de pesas",
                     detalle: pesasDetalle(s),
                     color: s.volumenDePesas.ahora > 0 ? Paleta.texto : Paleta.suave)

                Dato(valor: s.scoops.ahora > 0 ? String(format: "%.1f", s.scoops.ahora / 7) : "—",
                     rotulo: "Scoops por día",
                     detalle: s.scoops.ahora > 0
                            ? String(format: "%g en la semana", s.scoops.ahora) : "Nada anotado",
                     color: s.scoops.ahora > 0 ? Paleta.texto : Paleta.suave)

                Dato(valor: s.gastos.ahora > 0 ? Plata.corto(s.gastos.ahora) : "—",
                     rotulo: "Gastos",
                     detalle: gastosDetalle(s),
                     color: s.gastos.ahora > 0 ? Paleta.texto : Paleta.suave)

                Dato(valor: "\(s.diasActivos)/7",
                     rotulo: "Días con entrenamiento",
                     detalle: s.diasActivos == 0 ? "Ninguno todavía" : "Remo o pesas",
                     color: s.diasActivos > 0 ? Paleta.acento : Paleta.suave)
            }

            Bloque(titulo: "Remo día por día",
                   pie: "El punto azul marca los días que también hiciste pesas.") {
                BarrasDeLaSemana(dias: s.metrosPorDia)
            }

            if !s.observaciones.isEmpty {
                Bloque(titulo: "Lo que se nota") {
                    ForEach(enumerar(s.observaciones)) { fila in
                        if fila.puesto > 0 { Linea() }
                        Celda {
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Paleta.acento)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 7)
                                Text(fila.valor)
                                    .font(.system(size: 14))
                                    .foregroundColor(Paleta.texto)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            Bloque(titulo: "Contra la semana anterior") {
                Filas([
                    ("Peso promedio", conSigno(s.pesoPromedio, decimales: 2, unidad: " kg")),
                    ("Metros remados", conSigno(s.metros, decimales: 0, unidad: " m")),
                    ("Minutos remando", conSigno(s.minutosRemando, decimales: 0, unidad: " min")),
                    ("Sesiones de remo", conSigno(s.sesionesDeRemo, decimales: 0, unidad: "")),
                    ("Días de pesas", conSigno(s.diasDePesas, decimales: 0, unidad: "")),
                    ("Volumen de pesas", conSigno(s.volumenDePesas, decimales: 0, unidad: " kg")),
                    ("Scoops", conSigno(s.scoops, decimales: 1, unidad: "")),
                    ("Gastos", gastosComparado(s))
                ])
            }
        }
        .navigationTitle("La semana")
    }

    // MARK: Textos

    private func periodo(_ s: Semana) -> String {
        "Del " + Fechas.diaYMes(s.desde) + " al " + Fechas.diaYMes(s.hasta)
    }

    private func pesoTexto(_ s: Semana) -> String {
        guard s.pesoPromedio.ahora > 0 else { return "—" }
        guard s.pesoPromedio.hayConQueComparar else {
            return String(format: "%.1f", s.pesoPromedio.ahora)
        }
        return String(format: "%+.2f", s.pesoPromedio.cambio)
    }

    private func pesoDetalle(_ s: Semana) -> String {
        guard s.pesoPromedio.ahora > 0 else { return "Sin pesadas esta semana" }
        guard s.pesoPromedio.hayConQueComparar else {
            return "Promedio de \(s.pesadas) pesadas"
        }
        return String(format: "kg · promedio %.2f kg", s.pesoPromedio.ahora)
    }

    private func pesasDetalle(_ s: Semana) -> String {
        guard s.volumenDePesas.ahora > 0 else { return "Sin pesas esta semana" }
        let dias = Int(s.diasDePesas.ahora)
        return "kg en \(dias) " + (dias == 1 ? "día" : "días")
    }

    private func gastosDetalle(_ s: Semana) -> String {
        guard s.gastos.ahora > 0 else { return "Nada anotado" }
        guard s.gastos.hayConQueComparar else { return "Sin comparación" }
        let d = s.gastos.cambio
        return (d >= 0 ? "+" : "−") + Plata.corto(abs(d)) + " vs anterior"
    }

    private func comparar(_ par: Semana.Par, unidad: String) -> String {
        guard par.ahora > 0 || par.antes > 0 else { return "Nada esta semana" }
        guard par.hayConQueComparar else { return "Primera semana con datos" }
        let d = par.cambio
        return String(format: "%@%.0f%@ vs anterior", d >= 0 ? "+" : "−", abs(d), unidad)
    }

    private func conSigno(_ par: Semana.Par, decimales: Int, unidad: String) -> String {
        guard par.ahora > 0 || par.antes > 0 else { return "—" }
        let formato = "%+." + String(decimales) + "f"
        return String(format: formato, par.cambio) + unidad
    }

    private func gastosComparado(_ s: Semana) -> String {
        guard s.gastos.ahora > 0 || s.gastos.antes > 0 else { return "—" }
        let d = s.gastos.cambio
        return (d >= 0 ? "+" : "−") + Plata.corto(abs(d))
    }
}

/// Las barras de metros remados, dibujadas a mano.
///
/// No usa el gráfico que trae el sistema a propósito: así los días vacíos se
/// ven como huecos y se puede marcar abajo el día que hubo pesas.
struct BarrasDeLaSemana: View {
    let dias: [Semana.PuntoDeDia]

    private var techo: Double {
        max(dias.map(\.metros).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(dias) { dia in
                VStack(spacing: 5) {
                    Spacer(minLength: 0)

                    Text(dia.metros > 0 ? "\(Int(dia.metros))" : "")
                        .font(.system(size: 9, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(Paleta.suave)

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(dia.metros > 0
                              ? LinearGradient(colors: [Paleta.acento,
                                                        Paleta.acento.opacity(0.45)],
                                               startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [Paleta.borde, Paleta.borde],
                                               startPoint: .top, endPoint: .bottom))
                        .frame(height: alto(dia.metros))

                    Circle()
                        .fill(dia.huboPesas ? Paleta.acento : Color.clear)
                        .frame(width: 4, height: 4)

                    Text(inicial(dia.dia))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(esHoy(dia.dia) ? Paleta.texto : Paleta.suave)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 164)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func alto(_ metros: Double) -> CGFloat {
        guard metros > 0 else { return 3 }
        return max(8, CGFloat(metros / techo) * 104)
    }

    private func inicial(_ fecha: Date) -> String {
        Fechas.inicialDelDia(Calendar.current.component(.weekday, from: fecha))
    }

    private func esHoy(_ fecha: Date) -> Bool {
        Calendar.current.isDateInToday(fecha)
    }
}
