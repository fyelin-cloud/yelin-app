import Foundation

/// Lo que guarda la app además del peso y el remo: consumo, notas y gastos.
///
/// Mismo criterio que el resto: un CSV por cosa, texto plano, y todo sube a
/// Drive junto con lo demás.
extension Almacen {

    var urlConsumo: URL { documentos.appendingPathComponent("consumo.csv") }
    var urlNotas: URL { documentos.appendingPathComponent("notas.csv") }
    var urlGastos: URL { documentos.appendingPathComponent("gastos.csv") }
    var urlCategorias: URL { documentos.appendingPathComponent("categorias-gastos.txt") }

    static let categoriasPorDefecto = ["Comida", "Super", "Transporte", "Salidas",
                                       "Casa", "Salud", "Facultad", "Otros"]

    func prepararRegistros() {
        crearSiFalta(urlConsumo, encabezado: "instante,que,cantidad")
        crearSiFalta(urlNotas, encabezado: "instante,importante,carpeta,texto")
        crearSiFalta(urlGastos, encabezado: "instante,categoria,monto,detalle")
        prepararCarpetas()

        if !FileManager.default.fileExists(atPath: urlCategorias.path) {
            let cabecera = "# Las categorías de gastos, una por línea.\n"
                + "# Agregá o sacá las que quieras; las que empiezan con # no se usan.\n\n"
            try? (cabecera + Self.categoriasPorDefecto.joined(separator: "\n") + "\n")
                .write(to: urlCategorias, atomically: true, encoding: .utf8)
        }
    }

    // MARK: Consumo

    func cargarConsumo() -> [Consumo] {
        leerLineas(urlConsumo).compactMap { campos in
            guard campos.count >= 3, let instante = fechas.date(from: campos[0]) else { return nil }
            return Consumo(instante: instante, cantidad: Double(campos[2]) ?? 0, que: campos[1])
        }
    }

    func agregarConsumo(_ c: Consumo) {
        agregar(CSV.linea([fechas.string(from: c.instante), c.que,
                           String(format: "%g", c.cantidad)]), a: urlConsumo)
    }

    func reescribirConsumo(_ lista: [Consumo]) {
        escribir(["instante,que,cantidad"] + lista.map {
            CSV.linea([fechas.string(from: $0.instante), $0.que, String(format: "%g", $0.cantidad)])
        }, en: urlConsumo)
    }

    // MARK: Notas

    /// Lee las notas con carpeta y también las del formato viejo, que tenían
    /// tres columnas y ninguna carpeta. Esas quedan sin carpeta hasta que se
    /// muevan a una.
    func cargarNotas() -> [Nota] {
        leerLineas(urlNotas).compactMap { campos in
            guard campos.count >= 3, let instante = fechas.date(from: campos[0]) else { return nil }
            if campos.count >= 4 {
                return Nota(instante: instante, texto: campos[3],
                            importante: campos[1] == "si", carpeta: campos[2])
            }
            return Nota(instante: instante, texto: campos[2],
                        importante: campos[1] == "si", carpeta: "")
        }
    }

    func agregarNota(_ n: Nota) {
        agregar(CSV.linea([fechas.string(from: n.instante),
                           n.importante ? "si" : "no", n.carpeta, n.texto]), a: urlNotas)
    }

    func reescribirNotas(_ lista: [Nota]) {
        escribir(["instante,importante,carpeta,texto"] + lista.map {
            CSV.linea([fechas.string(from: $0.instante), $0.importante ? "si" : "no",
                       $0.carpeta, $0.texto])
        }, en: urlNotas)
    }

    // MARK: Carpetas de notas

    var urlCarpetas: URL { documentos.appendingPathComponent("carpetas-notas.txt") }

    static let carpetasPorDefecto = ["Facultad", "Personal", "Ideas"]

    func prepararCarpetas() {
        guard !FileManager.default.fileExists(atPath: urlCarpetas.path) else { return }
        let cabecera = "# Las carpetas de notas, una por línea.\n"
            + "# Sirven para separar por materia o por tema.\n"
            + "# Se pueden cambiar desde la app o acá; las que empiezan con # no se usan.\n\n"
        try? (cabecera + Self.carpetasPorDefecto.joined(separator: "\n") + "\n")
            .write(to: urlCarpetas, atomically: true, encoding: .utf8)
    }

    func cargarCarpetas() -> [String] {
        guard let texto = try? String(contentsOf: urlCarpetas, encoding: .utf8) else {
            return Self.carpetasPorDefecto
        }
        return texto.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    func guardarCarpetas(_ lista: [String]) {
        let cabecera = "# Las carpetas de notas, una por línea.\n"
            + "# Sirven para separar por materia o por tema.\n"
            + "# Se pueden cambiar desde la app o acá; las que empiezan con # no se usan.\n\n"
        try? (cabecera + lista.joined(separator: "\n") + "\n")
            .write(to: urlCarpetas, atomically: true, encoding: .utf8)
    }

    // MARK: Gastos

    func cargarGastos() -> [Gasto] {
        leerLineas(urlGastos).compactMap { campos in
            guard campos.count >= 4, let instante = fechas.date(from: campos[0]) else { return nil }
            return Gasto(instante: instante, monto: Double(campos[2]) ?? 0,
                         categoria: campos[1], detalle: campos[3])
        }
    }

    func agregarGasto(_ g: Gasto) {
        agregar(CSV.linea([fechas.string(from: g.instante), g.categoria,
                           String(format: "%.2f", g.monto), g.detalle]), a: urlGastos)
    }

    func reescribirGastos(_ lista: [Gasto]) {
        escribir(["instante,categoria,monto,detalle"] + lista.map {
            CSV.linea([fechas.string(from: $0.instante), $0.categoria,
                       String(format: "%.2f", $0.monto), $0.detalle])
        }, en: urlGastos)
    }

    func categorias() -> [String] {
        guard let texto = try? String(contentsOf: urlCategorias, encoding: .utf8) else {
            return Self.categoriasPorDefecto
        }
        let lista = texto.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        return lista.isEmpty ? Self.categoriasPorDefecto : lista
    }

    // MARK: Ayuda

    /// Lee un CSV salteando el encabezado. La usan también los otros archivos
    /// que viven en sus propios archivos de código, así que no es privada.
    func leerLineas(_ archivo: URL) -> [[String]] {
        guard let texto = try? String(contentsOf: archivo, encoding: .utf8) else { return [] }
        return texto.split(separator: "\n").dropFirst().map { CSV.campos($0) }
    }
}
