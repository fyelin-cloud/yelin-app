import Foundation

/// Un scoop de proteína (o lo que sea) anotado a una hora.
struct Consumo: Identifiable {
    let id = UUID()
    var instante: Date
    var cantidad: Double
    var que: String
}

/// Una nota suelta.
struct Nota: Identifiable {
    let id = UUID()
    var instante: Date
    var texto: String
    var importante: Bool
    /// Vacío quiere decir que todavía no está en ninguna carpeta.
    var carpeta: String = ""

    var titulo: String {
        let primera = texto.split(separator: "\n").first.map(String.init) ?? texto
        return primera.isEmpty ? "(vacía)" : primera
    }

    var resto: String {
        let lineas = texto.split(separator: "\n", omittingEmptySubsequences: false)
        return lineas.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}

/// Un gasto.
struct Gasto: Identifiable {
    let id = UUID()
    var instante: Date
    var monto: Double
    var categoria: String
    var detalle: String
}
