import Foundation

/// A dónde apunta cada cosa.
///
/// **Para qué sirve**: hasta ahora todos los números de la app eran absolutos
/// —81,12 kg, 3.420 m— y no decían si eso estaba bien o mal. Con un objetivo
/// cargado, las pantallas pueden mostrar cuánto falta en vez de solo cuánto
/// hubo.
///
/// Todos son opcionales: el que esté vacío simplemente no se muestra en
/// ningún lado.
struct Objetivos {
    var peso: Double?
    var metrosPorSemana: Double?
    var diasPorSemana: Int?
    var scoopsPorDia: Double?
    var topeDeGastos: Double?

    static let vacios = Objetivos()

    var hayAlguno: Bool {
        peso != nil || metrosPorSemana != nil || diasPorSemana != nil
            || scoopsPorDia != nil || topeDeGastos != nil
    }

    var cuantos: Int {
        [peso != nil, metrosPorSemana != nil, diasPorSemana != nil,
         scoopsPorDia != nil, topeDeGastos != nil].filter { $0 }.count
    }

    // MARK: Peso

    /// Cuánto falta para el peso objetivo. Negativo quiere decir que hay que
    /// bajar, positivo que hay que subir.
    func faltaParaElPeso(desde actual: Double?) -> Double? {
        guard let peso, let actual else { return nil }
        return peso - actual
    }

    /// Cuándo se llegaría al peso objetivo si la tendencia se mantuviera.
    ///
    /// Devuelve `nil` cuando la tendencia va para el otro lado o es tan chica
    /// que la fecha no significaría nada. **No es una promesa**: es la cuenta
    /// de dividir lo que falta por lo que viene cambiando cada semana.
    func fechaEstimada(desde actual: Double?, porSemana: Double?) -> Date? {
        guard let falta = faltaParaElPeso(desde: actual), let porSemana else { return nil }
        guard abs(falta) > 0.1, abs(porSemana) > 0.02 else { return nil }
        // Si la tendencia no apunta al objetivo, no hay fecha que dar.
        guard (falta > 0) == (porSemana > 0) else { return nil }
        let semanas = falta / porSemana
        guard semanas > 0, semanas < 260 else { return nil }
        return Calendar.current.date(byAdding: .day,
                                     value: Int((semanas * 7).rounded()), to: Date())
    }
}

// MARK: - Dónde se guardan

extension Almacen {

    var urlObjetivos: URL { documentos.appendingPathComponent("objetivos.csv") }

    func prepararObjetivos() {
        crearSiFalta(urlObjetivos, encabezado: "que,valor")
    }

    func cargarObjetivos() -> Objetivos {
        var o = Objetivos()
        for campos in leerLineas(urlObjetivos) where campos.count >= 2 {
            let valor = Double(campos[1])
            switch campos[0] {
            case "peso":            o.peso = valor
            case "metrosPorSemana": o.metrosPorSemana = valor
            case "diasPorSemana":   o.diasPorSemana = valor.map { Int($0) }
            case "scoopsPorDia":    o.scoopsPorDia = valor
            case "topeDeGastos":    o.topeDeGastos = valor
            default: break
            }
        }
        return o
    }

    func guardarObjetivos(_ o: Objetivos) {
        var lineas = ["que,valor"]
        func anotar(_ nombre: String, _ valor: Double?) {
            guard let valor else { return }
            lineas.append(CSV.linea([nombre, String(format: "%g", valor)]))
        }
        anotar("peso", o.peso)
        anotar("metrosPorSemana", o.metrosPorSemana)
        anotar("diasPorSemana", o.diasPorSemana.map(Double.init))
        anotar("scoopsPorDia", o.scoopsPorDia)
        anotar("topeDeGastos", o.topeDeGastos)
        escribir(lineas, en: urlObjetivos)
    }
}

/// Guarda los objetivos y avisa a las pantallas cuando cambian.
final class Metas: ObservableObject {

    @Published private(set) var objetivos: Objetivos

    private let sincronizador: Sincronizador

    init(sincronizador: Sincronizador) {
        self.sincronizador = sincronizador
        sincronizador.almacen.prepararObjetivos()
        objetivos = sincronizador.almacen.cargarObjetivos()
    }

    func guardar(_ nuevos: Objetivos) {
        objetivos = nuevos
        sincronizador.almacen.guardarObjetivos(nuevos)
        sincronizador.subirEnSegundoPlano()
    }
}
