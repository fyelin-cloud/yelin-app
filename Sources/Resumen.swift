import Foundation

/// Arma un archivo chico de texto con el estado actual de todo.
///
/// Sube a Drive junto con los CSV. La idea es que para preguntar "cómo vengo"
/// alcance con leer este archivo, en vez de procesar todo el historial.
enum Resumen {

    static func generar(almacen: Almacen) -> String {
        let pesadas = almacen.cargarPesadas()
        let sesiones = almacen.cargarSesiones()

        var l: [String] = []
        l.append("# Resumen de Yelin App")
        l.append("")
        l.append("Actualizado: \(fechaLarga(Date()))")
        l.append("")
        l.append(contentsOf: bloqueDePeso(pesadas))
        l.append("")
        l.append(contentsOf: bloqueDeRemo(sesiones))
        l.append("")
        l.append(contentsOf: bloqueDePesas(almacen.cargarSeries()))
        l.append("")
        l.append(contentsOf: bloqueDeProteina(almacen.cargarConsumo()))
        l.append("")
        l.append(contentsOf: bloqueDeGastos(almacen))
        l.append("")
        l.append(contentsOf: bloqueDeNotas(almacen.cargarNotas()))
        l.append("")
        l.append("## Archivos")
        l.append("")
        l.append("- `pesadas.csv` — una línea por pesada guardada")
        l.append("- `tramas.csv` — todo lo crudo que mandó la balanza")
        l.append("- `sesiones-remo.csv` — una línea por sesión de remo")
        l.append("- `tramas-remo.csv` — todo lo crudo que mandó la máquina")
        l.append("- `pesas.csv` — una línea por serie: ejercicio, repeticiones y kilos")
        l.append("- `consumo.csv` — scoops de proteína con su hora")
        l.append("- `notas.csv` — las notas, con fecha y si están marcadas")
        l.append("- `gastos.csv` — monto, categoría y detalle de cada gasto")
        l.append("")
        return l.joined(separator: "\n")
    }

    private static func bloqueDePeso(_ pesadas: [Pesada]) -> [String] {
        var l = ["## Peso", ""]
        guard !pesadas.isEmpty else {
            l.append("Todavía no hay pesadas.")
            return l
        }
        let puntos = Analisis.porDia(pesadas)
        let ordenadas = pesadas.sorted { $0.instante > $1.instante }

        if let ultima = ordenadas.first {
            l.append(String(format: "- Último: %.2f kg (%@)", ultima.kg, fechaLarga(ultima.instante)))
        }
        if let media = Analisis.promedioMovil(puntos).last {
            l.append(String(format: "- Promedio de 7 días: %.2f kg", media.kg))
        }
        l.append("- Cambio en 7 días: " + conSigno(Analisis.cambio(puntos, dias: 7)))
        l.append("- Cambio en 30 días: " + conSigno(Analisis.cambio(puntos, dias: 30)))
        if let tendencia = Analisis.tendenciaPorSemana(puntos) {
            l.append(String(format: "- Tendencia: %+.2f kg por semana", tendencia))
        } else {
            l.append("- Tendencia: faltan días para calcularla")
        }
        l.append("- Días con registro: \(puntos.count)")
        l.append("- Pesadas en total: \(pesadas.count)")
        return l
    }

    private static func bloqueDeRemo(_ sesiones: [SesionDeRemo]) -> [String] {
        var l = ["## Remo", ""]
        guard !sesiones.isEmpty else {
            l.append("Todavía no hay sesiones guardadas.")
            return l
        }
        let ordenadas = sesiones.sorted { $0.inicio > $1.inicio }
        let metros = sesiones.reduce(0.0) { $0 + $1.metros }
        let segundos = sesiones.reduce(0.0) { $0 + $1.segundosRemando }

        l.append("- Sesiones guardadas: \(sesiones.count)")
        l.append(String(format: "- Acumulado: %.0f m en %@ remando", metros, enHoras(segundos)))

        if let ultima = ordenadas.first {
            l.append(String(format: "- Última: %.0f m el %@, %@ remando, %@ cada 500 m, %.0f W",
                            ultima.metros,
                            fechaLarga(ultima.inicio),
                            enMinutos(ultima.segundosRemando),
                            enMinutos(ultima.ritmoPromedio),
                            ultima.wattsPromedio))
        }
        if let masLarga = sesiones.max(by: { $0.metros < $1.metros }) {
            l.append(String(format: "- La más larga: %.0f m el %@",
                            masLarga.metros, fechaCorta(masLarga.inicio)))
        }
        let conRitmo = sesiones.filter { $0.ritmoPromedio > 0 && $0.metros >= 500 }
        if let masRapida = conRitmo.min(by: { $0.ritmoPromedio < $1.ritmoPromedio }) {
            l.append(String(format: "- Mejor ritmo promedio: %@ cada 500 m, el %@",
                            enMinutos(masRapida.ritmoPromedio), fechaCorta(masRapida.inicio)))
        }
        l.append("")
        l.append("Nota: la distancia y el ritmo los calcula la app a partir del ritmo")
        l.append("instantáneo que informa la máquina, que no manda distancia. Falta")
        l.append("calibrarlos contra el display del aparato.")
        return l
    }

    private static func bloqueDePesas(_ series: [Serie]) -> [String] {
        var l = ["## Pesas", ""]
        guard !series.isEmpty else {
            l.append("Todavía no hay series anotadas.")
            return l
        }
        let calendario = Calendar.current
        var porDia: [Date: [Serie]] = [:]
        for s in series { porDia[calendario.startOfDay(for: s.instante), default: []].append(s) }
        let dias = porDia.keys.sorted(by: >)
        let volumenTotal = series.reduce(0.0) { $0 + $1.volumen }

        l.append("- Días entrenados: \(dias.count)")
        l.append("- Series en total: \(series.count)")
        l.append(String(format: "- Volumen acumulado: %.0f kg (repeticiones por kilos)", volumenTotal))

        if let ultimo = dias.first, let delDia = porDia[ultimo] {
            let volumen = delDia.reduce(0.0) { $0 + $1.volumen }
            l.append(String(format: "- Última sesión: %@, %.0f kg de volumen en %d series",
                            fechaCorta(ultimo), volumen, delDia.count))
            var nombres: [String] = []
            for s in delDia where !nombres.contains(s.ejercicio) { nombres.append(s.ejercicio) }
            for nombre in nombres {
                let suyas = delDia.filter { $0.ejercicio == nombre }
                l.append("  - \(nombre): " + suyas.map(\.resumen).joined(separator: ", "))
            }
        }

        var ejercicios: [String] = []
        for s in series where !ejercicios.contains(s.ejercicio) { ejercicios.append(s.ejercicio) }
        if !ejercicios.isEmpty {
            l.append("- Mejor kilaje por ejercicio:")
            for nombre in ejercicios.sorted() {
                let suyas = series.filter { $0.ejercicio == nombre }
                if let mejor = suyas.max(by: { $0.kilos < $1.kilos }) {
                    l.append("  - \(nombre): \(mejor.resumen) el \(fechaCorta(mejor.instante))")
                }
            }
        }
        return l
    }

    private static func bloqueDeProteina(_ consumo: [Consumo]) -> [String] {
        var l = ["## Proteína", ""]
        guard !consumo.isEmpty else {
            l.append("Todavía no hay nada anotado.")
            return l
        }
        let calendario = Calendar.current
        let hoy = consumo.filter { calendario.isDateInToday($0.instante) }
            .reduce(0.0) { $0 + $1.cantidad }
        l.append(String(format: "- Hoy: %g scoops", hoy))

        let desde = Date().addingTimeInterval(-7 * 86_400)
        let semana = consumo.filter { $0.instante >= desde }
        let total = semana.reduce(0.0) { $0 + $1.cantidad }
        l.append(String(format: "- Últimos 7 días: %g scoops (%.1f por día)", total, total / 7))
        if let ultimo = consumo.max(by: { $0.instante < $1.instante }) {
            l.append("- Último: \(fechaLarga(ultimo.instante))")
        }
        return l
    }

    private static func bloqueDeGastos(_ almacen: Almacen) -> [String] {
        var l = ["## Gastos", ""]
        let todos = almacen.cargarGastos()
        guard !todos.isEmpty else {
            l.append("Todavía no hay gastos anotados.")
            return l
        }
        let calendario = Calendar.current
        func delMes(_ atras: Int) -> [Gasto] {
            guard let base = calendario.date(byAdding: .month, value: -atras, to: Date()) else { return [] }
            let m = calendario.component(.month, from: base)
            let a = calendario.component(.year, from: base)
            return todos.filter {
                calendario.component(.month, from: $0.instante) == m
                    && calendario.component(.year, from: $0.instante) == a
            }
        }
        let esteMes = delMes(0), mesPasado = delMes(1)
        let total = esteMes.reduce(0.0) { $0 + $1.monto }
        l.append(String(format: "- Este mes: $%.0f en %d gastos", total, esteMes.count))
        if !mesPasado.isEmpty {
            let antes = mesPasado.reduce(0.0) { $0 + $1.monto }
            l.append(String(format: "- Mes pasado: $%.0f", antes))
        }
        var porCategoria: [String: Double] = [:]
        for g in esteMes { porCategoria[g.categoria, default: 0] += g.monto }
        for (categoria, monto) in porCategoria.sorted(by: { $0.value > $1.value }).prefix(5) {
            l.append(String(format: "  - %@: $%.0f", categoria, monto))
        }
        return l
    }

    private static func bloqueDeNotas(_ notas: [Nota]) -> [String] {
        var l = ["## Notas", ""]
        guard !notas.isEmpty else {
            l.append("Todavía no hay notas.")
            return l
        }
        l.append("- Total: \(notas.count)")
        let importantes = notas.filter(\.importante)
        if !importantes.isEmpty {
            l.append("- Marcadas como importantes:")
            for n in importantes.prefix(8) {
                l.append("  - \(n.titulo) (\(fechaCorta(n.instante)))")
            }
        }
        let ultimas = notas.sorted { $0.instante > $1.instante }.prefix(5)
        l.append("- Últimas:")
        for n in ultimas {
            l.append("  - \(n.titulo) (\(fechaCorta(n.instante)))")
        }
        l.append("")
        l.append("El texto completo de cada nota está en `notas.csv`.")
        return l
    }

    // MARK: Formato

    private static func fechaLarga(_ f: Date) -> String {
        let d = DateFormatter()
        d.locale = Locale(identifier: "es_AR")
        d.dateFormat = "d 'de' MMMM 'de' yyyy, HH:mm"
        return d.string(from: f)
    }

    private static func fechaCorta(_ f: Date) -> String {
        let d = DateFormatter()
        d.locale = Locale(identifier: "es_AR")
        d.dateFormat = "d/M/yyyy"
        return d.string(from: f)
    }

    private static func enMinutos(_ segundos: Double) -> String {
        let s = Int(segundos)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private static func enHoras(_ segundos: Double) -> String {
        let horas = Int(segundos) / 3600
        let minutos = (Int(segundos) % 3600) / 60
        return horas > 0 ? "\(horas) h \(minutos) min" : "\(minutos) min"
    }

    private static func conSigno(_ valor: Double?) -> String {
        guard let valor else { return "no hay historial suficiente" }
        return String(format: "%+.2f kg", valor)
    }
}
