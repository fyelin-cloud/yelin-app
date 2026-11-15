import Foundation

/// Una pesada ya interpretada.
struct Pesada: Identifiable {
    let id = UUID()
    let instante: Date
    let gramos: Int

    var kg: Double { Double(gramos) / 1000 }
}

/// Guarda las pesadas y las tramas crudas en archivos de texto dentro de la app.
///
/// Texto plano a propósito: se pueden abrir desde la app Archivos, mandar por
/// cualquier lado y leer sin la app.
final class Almacen {

    let urlPesadas: URL
    let urlTramas: URL

    private let fechas: ISO8601DateFormatter = {
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

        crearSiFalta(urlPesadas, encabezado: "instante,gramos,kg")
        crearSiFalta(urlTramas, encabezado: "instante,trama")
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
        let linea = "\(fechas.string(from: pesada.instante)),\(pesada.gramos),\(kg)"
        agregar(linea, a: urlPesadas)
    }

    func reescribirPesadas(_ pesadas: [Pesada]) {
        var lineas = ["instante,gramos,kg"]
        for p in pesadas {
            lineas.append("\(fechas.string(from: p.instante)),\(p.gramos),\(String(format: "%.3f", p.kg))")
        }
        try? (lineas.joined(separator: "\n") + "\n").write(to: urlPesadas,
                                                           atomically: true,
                                                           encoding: .utf8)
    }

    // MARK: Tramas crudas

    func agregarTrama(_ enHexa: String, instante: Date) {
        agregar("\(fechas.string(from: instante)),\(enHexa)", a: urlTramas)
    }

    func cantidadDeTramasGuardadas() -> Int {
        guard let texto = try? String(contentsOf: urlTramas, encoding: .utf8) else { return 0 }
        return max(0, texto.split(separator: "\n").count - 1)
    }

    // MARK: Archivos

    private func crearSiFalta(_ archivo: URL, encabezado: String) {
        guard !FileManager.default.fileExists(atPath: archivo.path) else { return }
        try? (encabezado + "\n").write(to: archivo, atomically: true, encoding: .utf8)
    }

    private func agregar(_ linea: String, a archivo: URL) {
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
