import Foundation

/// Un punto del gráfico de peso.
struct PuntoDePeso: Identifiable {
    let id = UUID()
    let fecha: Date
    let kg: Double
}

/// Cuentas sobre el historial de peso. Todo se calcula acá, no se guarda.
enum Analisis {

    /// Una pesada por día: si hay varias, se promedian.
    static func porDia(_ pesadas: [Pesada]) -> [PuntoDePeso] {
        let calendario = Calendar.current
        var sumas: [Date: (total: Double, cuenta: Int)] = [:]
        for p in pesadas {
            let dia = calendario.startOfDay(for: p.instante)
            let actual = sumas[dia] ?? (0, 0)
            sumas[dia] = (actual.total + p.kg, actual.cuenta + 1)
        }
        return sumas
            .map { PuntoDePeso(fecha: $0.key, kg: $0.value.total / Double($0.value.cuenta)) }
            .sorted { $0.fecha < $1.fecha }
    }

    /// Promedio móvil: para cada día, el promedio de los últimos N días.
    ///
    /// Es la línea que importa. Una pesada suelta tiene mucho ruido —ropa,
    /// agua, la hora— y el promedio lo filtra.
    static func promedioMovil(_ puntos: [PuntoDePeso], dias: Int = 7) -> [PuntoDePeso] {
        guard !puntos.isEmpty else { return [] }
        let ventana = Double(dias) * 86_400
        return puntos.map { punto in
            let desde = punto.fecha.addingTimeInterval(-ventana)
            let dentro = puntos.filter { $0.fecha > desde && $0.fecha <= punto.fecha }
            let suma = dentro.reduce(0.0) { $0 + $1.kg }
            return PuntoDePeso(fecha: punto.fecha, kg: suma / Double(max(dentro.count, 1)))
        }
    }

    /// Cuánto cambió el promedio en los últimos N días.
    static func cambio(_ puntos: [PuntoDePeso], dias: Int) -> Double? {
        let promedio = promedioMovil(puntos)
        guard let ultimo = promedio.last else { return nil }
        let corte = ultimo.fecha.addingTimeInterval(-Double(dias) * 86_400)
        guard let viejo = promedio.last(where: { $0.fecha <= corte }) else { return nil }
        return ultimo.kg - viejo.kg
    }

    /// Tendencia en kilos por semana, por cuadrados mínimos sobre los últimos
    /// días. Devuelve nada si no hay puntos suficientes para que signifique algo.
    static func tendenciaPorSemana(_ puntos: [PuntoDePeso], ultimosDias: Int = 30) -> Double? {
        guard let ultimo = puntos.last else { return nil }
        let desde = ultimo.fecha.addingTimeInterval(-Double(ultimosDias) * 86_400)
        let datos = puntos.filter { $0.fecha >= desde }
        guard datos.count >= 4 else { return nil }

        let base = datos[0].fecha.timeIntervalSince1970
        let xs = datos.map { ($0.fecha.timeIntervalSince1970 - base) / 86_400 }
        let ys = datos.map { $0.kg }
        let n = Double(datos.count)
        let sumaX = xs.reduce(0, +)
        let sumaY = ys.reduce(0, +)
        let sumaXY = zip(xs, ys).reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumaXX = xs.reduce(0.0) { $0 + $1 * $1 }

        let denominador = n * sumaXX - sumaX * sumaX
        guard abs(denominador) > 0.0001 else { return nil }
        let pendientePorDia = (n * sumaXY - sumaX * sumaY) / denominador
        return pendientePorDia * 7
    }

    /// Pesadas que se alejan mucho del promedio de su momento.
    static func sospechosas(_ puntos: [PuntoDePeso],
                            promedio: [PuntoDePeso],
                            margenKg: Double = 2.0) -> Set<UUID> {
        var raras: Set<UUID> = []
        for (punto, media) in zip(puntos, promedio) where abs(punto.kg - media.kg) > margenKg {
            raras.insert(punto.id)
        }
        return raras
    }

    /// El rango vertical del gráfico, con un poco de aire a cada lado.
    static func rangoVertical(_ puntos: [PuntoDePeso]) -> ClosedRange<Double> {
        let valores = puntos.map(\.kg)
        guard let minimo = valores.min(), let maximo = valores.max() else { return 0...100 }
        let aire = max((maximo - minimo) * 0.25, 0.5)
        return (minimo - aire)...(maximo + aire)
    }
}
