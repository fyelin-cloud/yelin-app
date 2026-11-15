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
        l.append("## Archivos")
        l.append("")
        l.append("- `pesadas.csv` — una línea por pesada guardada")
        l.append("- `tramas.csv` — todo lo crudo que mandó la balanza")
        l.append("- `sesiones-remo.csv` — una línea por sesión de remo")
        l.append("- `tramas-remo.csv` — todo lo crudo que mandó la máquina")
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
