import Foundation

/// Una pesada ya interpretada.
struct Pesada: Identifiable {
    let id = UUID()
    let instante: Date
    let gramos: Int

    var kg: Double { Double(gramos) / 1000 }
}

/// Una sesión de remo terminada.
///
/// La máquina borra todo al apagarse, así que esto es lo único que queda.
struct SesionDeRemo: Identifiable {
    let id = UUID()
    var inicio: Date
    var fin: Date
    var segundosRemando: Double
    var segundosTotales: Double
    var metros: Double
    var paladas: Int
    var wattsPromedio: Double

    /// Segundos cada 500 m, calculado sobre el total de la sesión.
    var ritmoPromedio: Double {
        guard metros > 0 else { return 0 }
        return segundosRemando / (metros / 500)
    }
}

/// Guarda todo en archivos de texto dentro de la app.
///
/// Texto plano a propósito: se pueden abrir desde la app Archivos, mandar por
/// cualquier lado y leer sin la app.
final class Almacen {

    let urlPesadas: URL
    let urlTramas: URL
    let urlSesiones: URL
    let urlTramasDeRemo: URL
    let urlResumen: URL
    private let urlSesionEnCurso: URL

    /// Todos los archivos que se suben a Drive.
    var archivosParaSubir: [URL] {
        [urlResumen, urlPesadas, urlTramas, urlSesiones, urlTramasDeRemo,
         urlConsumo, urlNotas, urlGastos, urlPesas, urlPanel, urlRecordatorios,
         urlObjetivos, urlCarpetas, urlLibreta] + imagenesDeLibreta
    }

    let fechas: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone.current
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init() {
        let documentos = FileManager.default.urls(for: .documentDirectory,
                                                  in: .userDomainMask)[0]
        urlPesadas = documentos.appendingPathComponent("pesadas.csv")
        urlTramas = documentos.appendingPathComponent("tramas.csv")
        urlSesiones = documentos.appendingPathComponent("sesiones-remo.csv")
        urlTramasDeRemo = documentos.appendingPathComponent("tramas-remo.csv")
        urlResumen = documentos.appendingPathComponent("resumen.md")
        urlSesionEnCurso = documentos.appendingPathComponent("sesion-en-curso.json")

        crearSiFalta(urlPesadas, encabezado: "instante,gramos,kg")
        crearSiFalta(urlTramas, encabezado: "instante,trama")
        crearSiFalta(urlSesiones,
                     encabezado: "inicio,fin,segundos_remando,segundos_totales,metros,paladas,watts_promedio,ritmo_500m")
        crearSiFalta(urlTramasDeRemo, encabezado: "instante,trama")
        prepararRegistros()
        prepararPesas()
        prepararRecordatorios()
        prepararLibreta()
    }

    var documentos: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: Pesadas

    func cargarPesadas() -> [Pesada] {
        guard let texto = try? String(contentsOf: urlPesadas, encoding: .utf8) else { return [] }
        var resultado: [Pesada] = []
        for linea in texto.split(separator: "\n").dropFirst() {
            let partes = linea.split(separator: ",")
            guard partes.count >= 2,
                  let instante = fechas.date(from: String(partes[0])),
                  let gramos = Int(partes[1]) else { continue }
            resultado.append(Pesada(instante: instante, gramos: gramos))
        }
        return resultado
    }

    func agregarPesada(_ pesada: Pesada) {
        let kg = String(format: "%.3f", pesada.kg)
        agregar("\(fechas.string(from: pesada.instante)),\(pesada.gramos),\(kg)", a: urlPesadas)
    }

    func reescribirPesadas(_ pesadas: [Pesada]) {
        var lineas = ["instante,gramos,kg"]
        for p in pesadas {
            lineas.append("\(fechas.string(from: p.instante)),\(p.gramos),\(String(format: "%.3f", p.kg))")
        }
        escribir(lineas, en: urlPesadas)
    }

    // MARK: Sesiones de remo

    func cargarSesiones() -> [SesionDeRemo] {
        guard let texto = try? String(contentsOf: urlSesiones, encoding: .utf8) else { return [] }
        var resultado: [SesionDeRemo] = []
        for linea in texto.split(separator: "\n").dropFirst() {
            let p = linea.split(separator: ",", omittingEmptySubsequences: false)
            guard p.count >= 7,
                  let inicio = fechas.date(from: String(p[0])),
                  let fin = fechas.date(from: String(p[1])) else { continue }
            resultado.append(SesionDeRemo(
                inicio: inicio,
                fin: fin,
                segundosRemando: Double(p[2]) ?? 0,
                segundosTotales: Double(p[3]) ?? 0,
                metros: Double(p[4]) ?? 0,
                paladas: Int(p[5]) ?? 0,
                wattsPromedio: Double(p[6]) ?? 0))
        }
        return resultado
    }

    func agregarSesion(_ s: SesionDeRemo) {
        let campos = [
            fechas.string(from: s.inicio),
            fechas.string(from: s.fin),
            String(format: "%.0f", s.segundosRemando),
            String(format: "%.0f", s.segundosTotales),
            String(format: "%.0f", s.metros),
            "\(s.paladas)",
            String(format: "%.0f", s.wattsPromedio),
            String(format: "%.0f", s.ritmoPromedio)
        ]
        agregar(campos.joined(separator: ","), a: urlSesiones)
    }

    func reescribirSesiones(_ sesiones: [SesionDeRemo]) {
        var lineas = ["inicio,fin,segundos_remando,segundos_totales,metros,paladas,watts_promedio,ritmo_500m"]
        for s in sesiones {
            lineas.append([
                fechas.string(from: s.inicio),
                fechas.string(from: s.fin),
                String(format: "%.0f", s.segundosRemando),
                String(format: "%.0f", s.segundosTotales),
                String(format: "%.0f", s.metros),
                "\(s.paladas)",
                String(format: "%.0f", s.wattsPromedio),
                String(format: "%.0f", s.ritmoPromedio)
            ].joined(separator: ","))
        }
        escribir(lineas, en: urlSesiones)
    }

    // MARK: Sesión a medio hacer
    //
    // Se guarda en cada palada. Si se corta el Bluetooth o se cierra la app,
    // al abrirla de nuevo la sesión se recupera en vez de perderse.

    func guardarEnCurso(_ s: SesionDeRemo) {
        let datos: [String: Any] = [
            "inicio": fechas.string(from: s.inicio),
            "fin": fechas.string(from: s.fin),
            "segundosRemando": s.segundosRemando,
            "segundosTotales": s.segundosTotales,
            "metros": s.metros,
            "paladas": s.paladas,
            "wattsPromedio": s.wattsPromedio
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: datos) else { return }
        try? json.write(to: urlSesionEnCurso, options: .atomic)
    }

    func leerEnCurso() -> SesionDeRemo? {
        guard let json = try? Data(contentsOf: urlSesionEnCurso),
              let d = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any],
              let textoInicio = d["inicio"] as? String,
              let textoFin = d["fin"] as? String,
              let inicio = fechas.date(from: textoInicio),
              let fin = fechas.date(from: textoFin) else { return nil }
        return SesionDeRemo(
            inicio: inicio,
            fin: fin,
            segundosRemando: d["segundosRemando"] as? Double ?? 0,
            segundosTotales: d["segundosTotales"] as? Double ?? 0,
            metros: d["metros"] as? Double ?? 0,
            paladas: d["paladas"] as? Int ?? 0,
            wattsPromedio: d["wattsPromedio"] as? Double ?? 0)
    }

    func borrarEnCurso() {
        try? FileManager.default.removeItem(at: urlSesionEnCurso)
    }

    // MARK: Resumen

    func escribirResumen(_ texto: String) {
        try? texto.write(to: urlResumen, atomically: true, encoding: .utf8)
    }

    // MARK: Tramas crudas

    func agregarTrama(_ enHexa: String, instante: Date) {
        agregar("\(fechas.string(from: instante)),\(enHexa)", a: urlTramas)
    }

    func agregarTramaDeRemo(_ enHexa: String, instante: Date) {
        agregar("\(fechas.string(from: instante)),\(enHexa)", a: urlTramasDeRemo)
    }

    /// Vuelca varias tramas de una, abriendo el archivo una sola vez.
    ///
    /// En una sesión larga llegan miles de tramas; escribir una por una sería
    /// abrir y cerrar el archivo miles de veces.
    func agregarTramasDeRemo(_ tandas: [(instante: Date, trama: String)]) {
        guard !tandas.isEmpty else { return }
        let texto = tandas
            .map { "\(fechas.string(from: $0.instante)),\($0.trama)" }
            .joined(separator: "\n")
        agregar(texto, a: urlTramasDeRemo)
    }

    // MARK: Archivos

    func crearSiFalta(_ archivo: URL, encabezado: String) {
        guard !FileManager.default.fileExists(atPath: archivo.path) else { return }
        try? (encabezado + "\n").write(to: archivo, atomically: true, encoding: .utf8)
    }

    func escribir(_ lineas: [String], en archivo: URL) {
        try? (lineas.joined(separator: "\n") + "\n")
            .write(to: archivo, atomically: true, encoding: .utf8)
    }

    func agregar(_ linea: String, a archivo: URL) {
        let datos = Data((linea + "\n").utf8)
        if let mango = try? FileHandle(forWritingTo: archivo) {
            defer { try? mango.close() }
            _ = try? mango.seekToEnd()
            try? mango.write(contentsOf: datos)
        } else {
            try? datos.write(to: archivo)
        }
    }
}
