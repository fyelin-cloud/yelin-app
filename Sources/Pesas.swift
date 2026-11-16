import Foundation

/// Una serie de un ejercicio: tantas repeticiones con tantos kilos.
///
/// Es la unidad más chica que vale la pena anotar. Una sesión de pesas no es
/// más que todas las series de un día.
struct Serie: Identifiable {
    let id = UUID()
    var instante: Date
    var ejercicio: String
    var repeticiones: Int
    var kilos: Double

    /// Repeticiones por kilos. Es la forma más simple de medir cuánto
    /// trabajo hizo el músculo, y la que sirve para comparar un día con otro.
    var volumen: Double { Double(repeticiones) * kilos }

    var resumen: String {
        let peso = kilos == kilos.rounded() ? String(format: "%.0f", kilos)
                                            : String(format: "%.1f", kilos)
        return "\(repeticiones) × \(peso) kg"
    }
}

/// Un día de pesas, con todo lo que se hizo.
struct DiaDePesas: Identifiable {
    var id: Date { dia }
    let dia: Date
    let series: [Serie]

    var volumen: Double { series.reduce(0) { $0 + $1.volumen } }
    var repeticiones: Int { series.reduce(0) { $0 + $1.repeticiones } }
    var ejercicios: [String] {
        var vistos: [String] = []
        for s in series where !vistos.contains(s.ejercicio) { vistos.append(s.ejercicio) }
        return vistos
    }
}

// MARK: - Dónde se guarda

extension Almacen {

    var urlPesas: URL { documentos.appendingPathComponent("pesas.csv") }
    var urlEjercicios: URL { documentos.appendingPathComponent("ejercicios.txt") }

    /// La lista con la que arranca la app. Se puede cambiar toda desde la
    /// pantalla de Pesas o editando el archivo a mano.
    static let ejerciciosPorDefecto = [
        "Sentadilla", "Peso muerto", "Zancadas",
        "Press de banca", "Press militar", "Aperturas",
        "Remo con mancuernas", "Dominadas", "Elevaciones laterales",
        "Curl de bíceps", "Extensión de tríceps", "Abdominales"
    ]

    func prepararPesas() {
        crearSiFalta(urlPesas, encabezado: "instante,ejercicio,repeticiones,kilos")
        guard !FileManager.default.fileExists(atPath: urlEjercicios.path) else { return }
        let cabecera = "# Los ejercicios que aparecen al anotar una serie, uno por línea.\n"
            + "# Agregá o sacá los que quieras; los que empiezan con # no se usan.\n"
            + "# También se pueden cambiar desde la pantalla de Pesas.\n\n"
        try? (cabecera + Self.ejerciciosPorDefecto.joined(separator: "\n") + "\n")
            .write(to: urlEjercicios, atomically: true, encoding: .utf8)
    }

    func cargarSeries() -> [Serie] {
        guard let texto = try? String(contentsOf: urlPesas, encoding: .utf8) else { return [] }
        return texto.split(separator: "\n").dropFirst().compactMap { linea in
            let campos = CSV.campos(linea)
            guard campos.count >= 4, let instante = fechas.date(from: campos[0]) else { return nil }
            return Serie(instante: instante,
                         ejercicio: campos[1],
                         repeticiones: Int(campos[2]) ?? 0,
                         kilos: Double(campos[3]) ?? 0)
        }
    }

    func agregarSerie(_ s: Serie) {
        agregar(CSV.linea([fechas.string(from: s.instante), s.ejercicio,
                           "\(s.repeticiones)", String(format: "%g", s.kilos)]),
                a: urlPesas)
    }

    func reescribirSeries(_ lista: [Serie]) {
        escribir(["instante,ejercicio,repeticiones,kilos"] + lista.map {
            CSV.linea([fechas.string(from: $0.instante), $0.ejercicio,
                       "\($0.repeticiones)", String(format: "%g", $0.kilos)])
        }, en: urlPesas)
    }

    func ejercicios() -> [String] {
        guard let texto = try? String(contentsOf: urlEjercicios, encoding: .utf8) else {
            return Self.ejerciciosPorDefecto
        }
        let lista = texto.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        return lista.isEmpty ? Self.ejerciciosPorDefecto : lista
    }

    func guardarEjercicios(_ lista: [String]) {
        let cabecera = "# Los ejercicios que aparecen al anotar una serie, uno por línea.\n"
            + "# Agregá o sacá los que quieras; los que empiezan con # no se usan.\n"
            + "# También se pueden cambiar desde la pantalla de Pesas.\n\n"
        try? (cabecera + lista.joined(separator: "\n") + "\n")
            .write(to: urlEjercicios, atomically: true, encoding: .utf8)
    }
}

// MARK: - El cuaderno de pesas

/// Las series de pesas y las preguntas que se le hacen.
///
/// Igual que el resto de la app: cada cambio se escribe en el CSV y dispara
/// la subida a Drive, sin botón de guardar.
final class Pesas: ObservableObject {

    @Published private(set) var series: [Serie] = []
    @Published private(set) var lista: [String] = []

    private let sincronizador: Sincronizador
    private var almacen: Almacen { sincronizador.almacen }

    init(sincronizador: Sincronizador) {
        self.sincronizador = sincronizador
        series = almacen.cargarSeries().sorted { $0.instante > $1.instante }
        lista = almacen.ejercicios()
    }

    private func subir() { sincronizador.subirEnSegundoPlano() }

    // MARK: Anotar

    func anotar(ejercicio: String, repeticiones: Int, kilos: Double) {
        let nombre = ejercicio.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty, repeticiones > 0 else { return }
        let nueva = Serie(instante: Date(), ejercicio: nombre,
                          repeticiones: repeticiones, kilos: max(0, kilos))
        almacen.agregarSerie(nueva)
        series.insert(nueva, at: 0)
        subir()
    }

    func borrar(_ s: Serie) {
        series.removeAll { $0.id == s.id }
        almacen.reescribirSeries(series)
        subir()
    }

    // MARK: La lista de ejercicios

    func agregarEjercicio(_ nombre: String) {
        let limpio = nombre.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty,
              !lista.contains(where: { $0.caseInsensitiveCompare(limpio) == .orderedSame })
        else { return }
        lista.append(limpio)
        lista.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        almacen.guardarEjercicios(lista)
        subir()
    }

    /// Saca el ejercicio de la lista pero **no** borra lo ya anotado: el
    /// historial queda, solo deja de ofrecerse al anotar una serie nueva.
    func quitarEjercicio(_ nombre: String) {
        lista.removeAll { $0 == nombre }
        almacen.guardarEjercicios(lista)
        subir()
    }

    // MARK: Hoy

    var seriesDeHoy: [Serie] {
        series.filter { Calendar.current.isDateInToday($0.instante) }
    }

    var volumenDeHoy: Double {
        seriesDeHoy.reduce(0) { $0 + $1.volumen }
    }

    /// Los ejercicios de hoy, en el orden en que se empezaron.
    var ejerciciosDeHoy: [String] {
        var vistos: [String] = []
        for s in seriesDeHoy.sorted(by: { $0.instante < $1.instante })
        where !vistos.contains(s.ejercicio) {
            vistos.append(s.ejercicio)
        }
        return vistos
    }

    func seriesDeHoy(de ejercicio: String) -> [Serie] {
        seriesDeHoy.filter { $0.ejercicio == ejercicio }
            .sorted { $0.instante < $1.instante }
    }

    // MARK: Historial

    /// Todos los días con pesas, del más nuevo al más viejo.
    func dias() -> [DiaDePesas] {
        let calendario = Calendar.current
        var porDia: [Date: [Serie]] = [:]
        for s in series {
            porDia[calendario.startOfDay(for: s.instante), default: []].append(s)
        }
        return porDia
            .map { DiaDePesas(dia: $0.key,
                              series: $0.value.sorted { $0.instante < $1.instante }) }
            .sorted { $0.dia > $1.dia }
    }

    /// La última vez que hizo este ejercicio, sin contar hoy. Es el dato que
    /// más sirve al momento de anotar: con cuánto venía.
    func ultimaVez(de ejercicio: String) -> DiaDePesas? {
        let calendario = Calendar.current
        let hoy = calendario.startOfDay(for: Date())
        let anteriores = series.filter {
            $0.ejercicio == ejercicio && calendario.startOfDay(for: $0.instante) < hoy
        }
        guard let ultima = anteriores.first else { return nil }
        let dia = calendario.startOfDay(for: ultima.instante)
        let delDia = anteriores.filter { calendario.startOfDay(for: $0.instante) == dia }
        return DiaDePesas(dia: dia, series: delDia.sorted { $0.instante < $1.instante })
    }

    /// Con cuánto conviene arrancar al anotar: lo último que levantó en ese
    /// ejercicio, sea de hoy o de la vez anterior.
    func sugerencia(para ejercicio: String) -> Serie? {
        series.first { $0.ejercicio == ejercicio }
    }

    /// El kilaje más alto que levantó en ese ejercicio.
    func record(de ejercicio: String) -> Serie? {
        series.filter { $0.ejercicio == ejercicio }
            .max { izq, der in
                izq.kilos != der.kilos ? izq.kilos < der.kilos
                                       : izq.repeticiones < der.repeticiones
            }
    }

    /// Los ejercicios que alguna vez anotó, aunque ya no estén en la lista.
    func ejerciciosConHistorial() -> [String] {
        var vistos: [String] = []
        for s in series where !vistos.contains(s.ejercicio) { vistos.append(s.ejercicio) }
        return vistos.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
