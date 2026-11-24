import Foundation

/// Una hoja escrita a mano con el Pencil.
///
/// El dibujo en sí no entra en un CSV: son bytes. Por eso cada hoja son **dos
/// archivos** adentro de la carpeta `libreta/`:
///
/// - `<id>.dibujo` — lo que guarda PencilKit, que es lo único con lo que se
///   puede seguir escribiendo encima.
/// - `<id>.png` — la misma hoja como imagen, para mirarla desde la
///   computadora y para que suba a Drive.
///
/// En `libreta.csv` va solo la ficha: título, carpeta y fechas.
struct Pagina: Identifiable {
    let id: String
    var titulo: String
    var carpeta: String
    var creada: Date
    var modificada: Date

    static func nueva(carpeta: String = "") -> Pagina {
        let ahora = Date()
        return Pagina(id: UUID().uuidString, titulo: "", carpeta: carpeta,
                      creada: ahora, modificada: ahora)
    }

    /// Lo que se muestra en la lista cuando todavía no le puso nombre.
    var nombreVisible: String {
        let limpio = titulo.trimmingCharacters(in: .whitespaces)
        return limpio.isEmpty ? "Hoja del " + Fechas.conAnio(creada) : limpio
    }
}

// MARK: - Dónde se guardan

extension Almacen {

    var carpetaDeLibreta: URL { documentos.appendingPathComponent("libreta") }
    var urlLibreta: URL { documentos.appendingPathComponent("libreta.csv") }

    func prepararLibreta() {
        crearSiFalta(urlLibreta, encabezado: "id,creada,modificada,carpeta,titulo")
        try? FileManager.default.createDirectory(at: carpetaDeLibreta,
                                                 withIntermediateDirectories: true)
    }

    func urlDelDibujo(_ id: String) -> URL {
        carpetaDeLibreta.appendingPathComponent("\(id).dibujo")
    }

    func urlDeLaImagen(_ id: String) -> URL {
        carpetaDeLibreta.appendingPathComponent("\(id).png")
    }

    func cargarPaginas() -> [Pagina] {
        leerLineas(urlLibreta).compactMap { c in
            guard c.count >= 5,
                  let creada = fechas.date(from: c[1]),
                  let modificada = fechas.date(from: c[2]) else { return nil }
            return Pagina(id: c[0], titulo: c[4], carpeta: c[3],
                          creada: creada, modificada: modificada)
        }
    }

    func guardarPaginas(_ lista: [Pagina]) {
        escribir(["id,creada,modificada,carpeta,titulo"] + lista.map {
            CSV.linea([$0.id, fechas.string(from: $0.creada),
                       fechas.string(from: $0.modificada), $0.carpeta, $0.titulo])
        }, en: urlLibreta)
    }

    func guardarDibujo(_ datos: Data, de id: String) {
        try? datos.write(to: urlDelDibujo(id), options: .atomic)
    }

    func cargarDibujo(_ id: String) -> Data? {
        try? Data(contentsOf: urlDelDibujo(id))
    }

    func guardarImagen(_ datos: Data, de id: String) {
        try? datos.write(to: urlDeLaImagen(id), options: .atomic)
    }

    func borrarArchivosDe(_ id: String) {
        try? FileManager.default.removeItem(at: urlDelDibujo(id))
        try? FileManager.default.removeItem(at: urlDeLaImagen(id))
    }

    /// Las imágenes de las hojas, para que suban a Drive junto con lo demás.
    var imagenesDeLibreta: [URL] {
        guard let todo = try? FileManager.default.contentsOfDirectory(
            at: carpetaDeLibreta, includingPropertiesForKeys: nil) else { return [] }
        return todo.filter { $0.pathExtension == "png" }.sorted { $0.path < $1.path }
    }
}

// MARK: - El cuaderno

/// Las hojas de la libreta y lo que se puede hacer con ellas.
final class Libreta: ObservableObject {

    @Published private(set) var paginas: [Pagina] = []

    private let sincronizador: Sincronizador
    private var almacen: Almacen { sincronizador.almacen }

    init(sincronizador: Sincronizador) {
        self.sincronizador = sincronizador
        sincronizador.almacen.prepararLibreta()
        paginas = sincronizador.almacen.cargarPaginas()
            .sorted { $0.modificada > $1.modificada }
    }

    private func guardarFichas() {
        almacen.guardarPaginas(paginas)
        sincronizador.subirEnSegundoPlano()
    }

    // MARK: Crear y borrar

    func crear(en carpeta: String) -> Pagina {
        let hoja = Pagina.nueva(carpeta: carpeta)
        paginas.insert(hoja, at: 0)
        guardarFichas()
        return hoja
    }

    func borrar(_ hoja: Pagina) {
        paginas.removeAll { $0.id == hoja.id }
        almacen.borrarArchivosDe(hoja.id)
        guardarFichas()
    }

    // MARK: Cambiar

    func renombrar(_ hoja: Pagina, a titulo: String) {
        cambiar(hoja) { $0.titulo = titulo.trimmingCharacters(in: .whitespaces) }
    }

    func mover(_ hoja: Pagina, a carpeta: String) {
        cambiar(hoja) { $0.carpeta = carpeta }
    }

    private func cambiar(_ hoja: Pagina, _ ajuste: (inout Pagina) -> Void) {
        guard let donde = paginas.firstIndex(where: { $0.id == hoja.id }) else { return }
        ajuste(&paginas[donde])
        paginas[donde].modificada = Date()
        ordenar()
        guardarFichas()
    }

    /// Guarda lo escrito. Se llama sola mientras él escribe, no hay botón.
    ///
    /// La imagen se regenera en cada guardado: es lo que después mira desde la
    /// computadora, así que tiene que estar al día.
    func guardarDibujo(_ datos: Data, imagen: Data?, de id: String) {
        almacen.guardarDibujo(datos, de: id)
        if let imagen { almacen.guardarImagen(imagen, de: id) }
        if let donde = paginas.firstIndex(where: { $0.id == id }) {
            paginas[donde].modificada = Date()
            ordenar()
        }
        guardarFichas()
    }

    func dibujoDe(_ id: String) -> Data? { almacen.cargarDibujo(id) }

    func imagenDe(_ id: String) -> URL { almacen.urlDeLaImagen(id) }

    func hayImagen(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: almacen.urlDeLaImagen(id).path)
    }

    private func ordenar() {
        paginas.sort { $0.modificada > $1.modificada }
    }

    // MARK: Preguntas

    func paginas(en carpeta: String?) -> [Pagina] {
        guard let carpeta else { return paginas.filter { $0.carpeta.isEmpty } }
        return paginas.filter { $0.carpeta == carpeta }
    }

    func cuantasEn(_ carpeta: String) -> Int {
        paginas.filter { $0.carpeta == carpeta }.count
    }

    var sinCarpeta: Int { paginas.filter { $0.carpeta.isEmpty }.count }

    func coinciden(con texto: String) -> [Pagina] {
        let limpio = texto.trimmingCharacters(in: .whitespaces)
        guard !limpio.isEmpty else { return paginas }
        return paginas.filter {
            $0.nombreVisible.localizedCaseInsensitiveContains(limpio)
                || $0.carpeta.localizedCaseInsensitiveContains(limpio)
        }
    }
}
