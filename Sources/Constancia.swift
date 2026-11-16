import Foundation

/// Qué días hubo actividad en los últimos tres meses.
///
/// La app ya guarda todo lo que pasó, pero hasta ahora no había forma de ver
/// de un saque si una semana fue vacía o cargada. Esto es eso: una grilla de
/// días, uno por cuadradito.
struct Constancia {

    struct Dia: Identifiable {
        var id: Date { dia }
        let dia: Date
        let remo: Bool
        let pesas: Bool
        let pesada: Bool
        let esFuturo: Bool

        var entreno: Bool { remo || pesas }

        /// 0 nada, 1 solo se pesó, 2 entrenó una cosa, 3 remo y pesas.
        var nivel: Int {
            if remo && pesas { return 3 }
            if entreno { return 2 }
            if pesada { return 1 }
            return 0
        }
    }

    /// Columnas de siete días, de la semana más vieja a la más nueva.
    let semanas: [[Dia]]
    let rachaActual: Int
    let rachaMasLarga: Int
    let entrenadosEnTreinta: Int
    let diasConPesada: Int
    let totalEntrenados: Int

    static func armar(pesadas: [Pesada],
                      sesiones: [SesionDeRemo],
                      series: [Serie],
                      semanasAtras: Int = 13) -> Constancia {

        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())

        // Un conjunto por cosa, así preguntar por un día es inmediato en vez
        // de recorrer todo el historial noventa veces.
        func diasDe<T>(_ lista: [T], fecha: (T) -> Date) -> Set<Date> {
            Set(lista.map { calendario.startOfDay(for: fecha($0)) })
        }
        let conPesada = diasDe(pesadas) { $0.instante }
        let conRemo = diasDe(sesiones) { $0.inicio }
        let conPesas = diasDe(series) { $0.instante }

        // La grilla arranca al principio de la semana, si no los cuadraditos
        // quedan corridos y no se lee por columnas.
        let atras = -(semanasAtras * 7 - 1)
        let crudo = calendario.date(byAdding: .day, value: atras, to: hoy) ?? hoy
        var inicio = crudo
        while calendario.component(.weekday, from: inicio) != calendario.firstWeekday {
            inicio = calendario.date(byAdding: .day, value: -1, to: inicio) ?? inicio
        }

        var semanas: [[Dia]] = []
        var actual: [Dia] = []
        var cursor = inicio
        while cursor <= hoy || actual.count % 7 != 0 {
            let dia = Dia(dia: cursor,
                          remo: conRemo.contains(cursor),
                          pesas: conPesas.contains(cursor),
                          pesada: conPesada.contains(cursor),
                          esFuturo: cursor > hoy)
            actual.append(dia)
            if actual.count == 7 {
                semanas.append(actual)
                actual = []
            }
            guard let siguiente = calendario.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = siguiente
        }
        if !actual.isEmpty { semanas.append(actual) }

        // MARK: Rachas

        let entrenados = conRemo.union(conPesas)

        var racha = 0
        var cursorRacha = hoy
        while entrenados.contains(cursorRacha) {
            racha += 1
            guard let anterior = calendario.date(byAdding: .day, value: -1, to: cursorRacha) else { break }
            cursorRacha = anterior
        }

        var masLarga = 0
        var corriendo = 0
        let ordenados = entrenados.sorted()
        var anteriorDia: Date?
        for dia in ordenados {
            if let previo = anteriorDia,
               let siguiente = calendario.date(byAdding: .day, value: 1, to: previo),
               calendario.isDate(siguiente, inSameDayAs: dia) {
                corriendo += 1
            } else {
                corriendo = 1
            }
            masLarga = max(masLarga, corriendo)
            anteriorDia = dia
        }

        let hace30 = calendario.date(byAdding: .day, value: -29, to: hoy) ?? hoy
        let enTreinta = entrenados.filter { $0 >= hace30 && $0 <= hoy }.count

        return Constancia(semanas: semanas,
                          rachaActual: racha,
                          rachaMasLarga: masLarga,
                          entrenadosEnTreinta: enTreinta,
                          diasConPesada: conPesada.count,
                          totalEntrenados: entrenados.count)
    }
}
