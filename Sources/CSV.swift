import Foundation

/// Leer y escribir líneas de CSV sin romperse con comas ni comillas.
///
/// Los saltos de línea dentro de un campo se guardan como `\n` literal, así
/// cada registro ocupa siempre una sola línea del archivo. Es una concesión
/// chica que mantiene los archivos simples de leer con cualquier cosa.
enum CSV {

    static func linea(_ campos: [String]) -> String {
        campos.map(escapar).joined(separator: ",")
    }

    static func campos(_ linea: Substring) -> [String] {
        campos(String(linea))
    }

    static func campos(_ linea: String) -> [String] {
        var resultado: [String] = []
        var actual = ""
        var entreComillas = false
        var i = linea.startIndex

        while i < linea.endIndex {
            let c = linea[i]
            if entreComillas {
                if c == "\"" {
                    let siguiente = linea.index(after: i)
                    if siguiente < linea.endIndex, linea[siguiente] == "\"" {
                        actual.append("\"")
                        i = siguiente
                    } else {
                        entreComillas = false
                    }
                } else {
                    actual.append(c)
                }
            } else {
                switch c {
                case "\"": entreComillas = true
                case ",":  resultado.append(desescapar(actual)); actual = ""
                default:   actual.append(c)
                }
            }
            i = linea.index(after: i)
        }
        resultado.append(desescapar(actual))
        return resultado
    }

    private static func escapar(_ campo: String) -> String {
        let plano = campo.replacingOccurrences(of: "\n", with: "\\n")
        guard plano.contains(",") || plano.contains("\"") else { return plano }
        return "\"" + plano.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func desescapar(_ campo: String) -> String {
        campo.replacingOccurrences(of: "\\n", with: "\n")
    }
}
