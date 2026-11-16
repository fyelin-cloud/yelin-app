import Foundation

/// Los últimos siete días contra los siete anteriores.
///
/// Es el único lugar de la app donde se cruzan todos los datos. El resto de
/// las pantallas mira una cosa cada una; acá se ve si la semana fue mejor o
/// peor que la anterior, que es la pregunta real.
struct Semana {

    /// Un número de esta semana y el mismo de la anterior.
    struct Par {
        let ahora: Double
        let antes: Double

        var cambio: Double { ahora - antes }

        /// Cuánto cambió en porcentaje. `nil` cuando la semana anterior
        /// estaba en cero y no hay contra qué comparar.
        var porcentaje: Double? {
            guard antes > 0 else { return nil }
            return (ahora - antes) / antes * 100
        }

        var hayConQueComparar: Bool { antes > 0 }
    }

    let desde: Date
    let hasta: Date

    let pesoPromedio: Par
    let pesadas: Int
    let ultimoPeso: Double?

    let metros: Par
    let minutosRemando: Par
    let sesionesDeRemo: Par

    let volumenDePesas: Par
    let diasDePesas: Par

    let scoops: Par
    let gastos: Par

    let diasActivos: Int
    let metrosPorDia: [PuntoDeDia]

    struct PuntoDeDia: Identifiable {
        var id: Date { dia }
        let dia: Date
        let metros: Double
        let huboPesas: Bool
        let huboPesada: Bool
    }

    // MARK: Armado

    static func armar(pesadas listaDePesadas: [Pesada],
                      sesiones: [SesionDeRemo],
                      consumo: [Consumo],
                      gastos listaDeGastos: [Gasto],
                      series: [Serie]) -> Semana {

        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())
        let desde = calendario.date(byAdding: .day, value: -6, to: hoy) ?? hoy
        let desdeAntes = calendario.date(byAdding: .day, value: -13, to: hoy) ?? hoy
        let hastaAntes = calendario.date(byAdding: .day, value: -7, to: hoy) ?? hoy

        func estaEnEsta(_ fecha: Date) -> Bool {
            let dia = calendario.startOfDay(for: fecha)
            return dia >= desde && dia <= hoy
        }
        func estaEnLaAnterior(_ fecha: Date) -> Bool {
            let dia = calendario.startOfDay(for: fecha)
            return dia >= desdeAntes && dia <= hastaAntes
        }
        func par(_ esta: Double, _ anterior: Double) -> Par {
            Par(ahora: esta, antes: anterior)
        }

        // Peso: se compara el promedio de cada semana, que aguanta mejor una
        // pesada mal tomada que el primer y el último valor.
        let pesoEsta = listaDePesadas.filter { estaEnEsta($0.instante) }.map(\.kg)
        let pesoAntes = listaDePesadas.filter { estaEnLaAnterior($0.instante) }.map(\.kg)
        let promedioEsta = pesoEsta.isEmpty ? 0 : pesoEsta.reduce(0, +) / Double(pesoEsta.count)
        let promedioAntes = pesoAntes.isEmpty ? 0 : pesoAntes.reduce(0, +) / Double(pesoAntes.count)

        let remoEsta = sesiones.filter { estaEnEsta($0.inicio) }
        let remoAntes = sesiones.filter { estaEnLaAnterior($0.inicio) }

        let pesasEsta = series.filter { estaEnEsta($0.instante) }
        let pesasAntes = series.filter { estaEnLaAnterior($0.instante) }
        func diasDistintos(_ lista: [Serie]) -> Double {
            Double(Set(lista.map { calendario.startOfDay(for: $0.instante) }).count)
        }

        let scoopsEsta = consumo.filter { estaEnEsta($0.instante) }.reduce(0.0) { $0 + $1.cantidad }
        let scoopsAntes = consumo.filter { estaEnLaAnterior($0.instante) }.reduce(0.0) { $0 + $1.cantidad }

        let gastoEsta = listaDeGastos.filter { estaEnEsta($0.instante) }.reduce(0.0) { $0 + $1.monto }
        let gastoAntes = listaDeGastos.filter { estaEnLaAnterior($0.instante) }.reduce(0.0) { $0 + $1.monto }

        // Un punto por cada uno de los siete días, incluso los vacíos: si
        // falta un día el gráfico tiene que mostrar el hueco.
        var puntos: [PuntoDeDia] = []
        for atras in stride(from: 6, through: 0, by: -1) {
            guard let dia = calendario.date(byAdding: .day, value: -atras, to: hoy) else { continue }
            let metrosDelDia = sesiones
                .filter { calendario.isDate($0.inicio, inSameDayAs: dia) }
                .reduce(0.0) { $0 + $1.metros }
            puntos.append(PuntoDeDia(
                dia: dia,
                metros: metrosDelDia,
                huboPesas: series.contains { calendario.isDate($0.instante, inSameDayAs: dia) },
                huboPesada: listaDePesadas.contains { calendario.isDate($0.instante, inSameDayAs: dia) }))
        }

        let activos = puntos.filter { $0.metros > 0 || $0.huboPesas }.count

        return Semana(
            desde: desde,
            hasta: hoy,
            pesoPromedio: par(promedioEsta, promedioAntes),
            pesadas: pesoEsta.count,
            ultimoPeso: listaDePesadas.max(by: { $0.instante < $1.instante })?.kg,
            metros: par(remoEsta.reduce(0) { $0 + $1.metros },
                        remoAntes.reduce(0) { $0 + $1.metros }),
            minutosRemando: par(remoEsta.reduce(0) { $0 + $1.segundosRemando } / 60,
                                remoAntes.reduce(0) { $0 + $1.segundosRemando } / 60),
            sesionesDeRemo: par(Double(remoEsta.count), Double(remoAntes.count)),
            volumenDePesas: par(pesasEsta.reduce(0) { $0 + $1.volumen },
                                pesasAntes.reduce(0) { $0 + $1.volumen }),
            diasDePesas: par(diasDistintos(pesasEsta), diasDistintos(pesasAntes)),
            scoops: par(scoopsEsta, scoopsAntes),
            gastos: par(gastoEsta, gastoAntes),
            diasActivos: activos,
            metrosPorDia: puntos)
    }

    // MARK: Lo que se nota

    /// Tres o cuatro frases con lo que cambió de una semana a la otra.
    ///
    /// A propósito son descripciones y no consejos: dicen qué pasó, no qué
    /// habría que hacer.
    var observaciones: [String] {
        var frases: [String] = []

        if pesoPromedio.ahora > 0 && pesoPromedio.hayConQueComparar {
            let d = pesoPromedio.cambio
            if abs(d) < 0.15 {
                frases.append("El peso quedó igual que la semana pasada.")
            } else {
                frases.append(String(format: "El peso promedio %@ %.2f kg.",
                                     d > 0 ? "subió" : "bajó", abs(d)))
            }
        } else if pesadas == 0 {
            frases.append("No te pesaste ningún día de esta semana.")
        }

        if metros.ahora == 0 && metros.antes > 0 {
            frases.append(String(format: "No remaste nada; la semana pasada habías hecho %.0f m.", metros.antes))
        } else if metros.ahora > 0 {
            if metros.hayConQueComparar {
                let d = metros.cambio
                frases.append(String(format: "Remaste %.0f m, %.0f m %@ que la semana pasada.",
                                     metros.ahora, abs(d), d >= 0 ? "más" : "menos"))
            } else {
                frases.append(String(format: "Remaste %.0f m en %.0f sesiones.",
                                     metros.ahora, sesionesDeRemo.ahora))
            }
        }

        if volumenDePesas.ahora > 0 {
            frases.append(String(format: "Pesas: %.0f días y %@ kg de volumen.",
                                 diasDePesas.ahora, Kilos.grande(volumenDePesas.ahora)))
        } else if volumenDePesas.antes > 0 {
            frases.append("No anotaste pesas esta semana.")
        }

        if scoops.ahora > 0 {
            frases.append(String(format: "Proteína: %.1f scoops por día en promedio.", scoops.ahora / 7))
        }

        if gastos.ahora > 0 && gastos.hayConQueComparar {
            let d = gastos.cambio
            frases.append("Gastaste " + Plata.corto(abs(d))
                          + (d >= 0 ? " más" : " menos") + " que la semana pasada.")
        }

        if diasActivos == 0 {
            frases.append("Ningún día con entrenamiento en los últimos siete.")
        } else if diasActivos >= 5 {
            frases.append("Entrenaste \(diasActivos) de los últimos 7 días.")
        }

        return frases
    }
}
