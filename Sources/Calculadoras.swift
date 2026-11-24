import Foundation

/// Lo que tiene en casa para levantar: la barra, los discos y las mancuernas.
struct Equipo {
    var barra: Double = 20
    /// Kilos de cada disco y cuántos tiene **en total**, no por lado.
    var discos: [Disco] = []
    var mancuernas: [Double] = []

    struct Disco: Identifiable, Equatable {
        var id: String { String(format: "%g", kilos) }
        var kilos: Double
        var cuantos: Int
        var pares: Int { cuantos / 2 }
    }

    static let porDefecto = Equipo(
        barra: 20,
        discos: [Disco(kilos: 20, cuantos: 2), Disco(kilos: 10, cuantos: 4),
                 Disco(kilos: 5, cuantos: 4), Disco(kilos: 2.5, cuantos: 4),
                 Disco(kilos: 1.25, cuantos: 2)],
        mancuernas: [])

    var hayDiscos: Bool { discos.contains { $0.pares > 0 } }

    /// El total más pesado que se puede armar con lo que hay.
    var maximo: Double {
        barra + discos.reduce(0) { $0 + $1.kilos * Double($1.pares) * 2 }
    }
}

/// Qué discos poner de cada lado para llegar a un peso.
struct Armado {
    /// Kilos de cada disco y cuántos de ese van **por lado**.
    let porLado: [(kilos: Double, cuantos: Int)]
    let total: Double
    let pedido: Double

    var exacto: Bool { abs(total - pedido) < 0.01 }

    var texto: String {
        guard !porLado.isEmpty else { return "Solo la barra" }
        return porLado.map { par in
            par.cuantos == 1 ? String(format: "%g", par.kilos)
                             : String(format: "%g × %d", par.kilos, par.cuantos)
        }.joined(separator: " + ")
    }
}

enum Calculo {

    // MARK: Repetición máxima

    /// El peso que levantaría una sola vez, estimado con la fórmula de Epley.
    ///
    /// Es una **estimación**, no una medición: cuantas más repeticiones tenga
    /// la serie de la que sale, menos confiable es. Arriba de diez ya conviene
    /// tomarla como orientativa nomás.
    static func maximaEstimada(peso: Double, repeticiones: Int) -> Double? {
        guard peso > 0, repeticiones > 0, repeticiones <= 30 else { return nil }
        if repeticiones == 1 { return peso }
        return peso * (1 + Double(repeticiones) / 30)
    }

    /// Qué tan confiable es la estimación según de cuántas repeticiones sale.
    static func confianza(_ repeticiones: Int) -> String {
        switch repeticiones {
        case 1:     return "Es el valor real, no una estimación"
        case 2...6: return "Estimación confiable"
        case 7...10: return "Estimación aceptable"
        default:    return "Con tantas repeticiones es solo orientativa"
        }
    }

    static let porcentajes = [95, 90, 85, 80, 75, 70, 65, 60, 50]

    // MARK: Discos

    /// Reparte los discos de a pares, del más pesado al más liviano.
    ///
    /// Va de a pares porque la barra tiene que quedar equilibrada, y nunca se
    /// pasa del peso pedido: si no llega justo, queda un poco abajo y se
    /// avisa cuánto falta.
    static func armar(_ pedido: Double, con equipo: Equipo) -> Armado {
        var falta = pedido - equipo.barra
        guard falta > 0 else {
            return Armado(porLado: [], total: equipo.barra, pedido: pedido)
        }
        var puestos: [(kilos: Double, cuantos: Int)] = []
        var total = equipo.barra

        for disco in equipo.discos.sorted(by: { $0.kilos > $1.kilos }) where disco.pares > 0 {
            let cabenPorPeso = Int(falta / (disco.kilos * 2))
            let cuantos = min(cabenPorPeso, disco.pares)
            guard cuantos > 0 else { continue }
            puestos.append((kilos: disco.kilos, cuantos: cuantos))
            let sumado = disco.kilos * Double(cuantos) * 2
            total += sumado
            falta -= sumado
        }
        return Armado(porLado: puestos, total: total, pedido: pedido)
    }
}

// MARK: - Dónde se guarda

extension Almacen {

    var urlEquipo: URL { documentos.appendingPathComponent("equipo.csv") }

    func prepararEquipo() {
        guard !FileManager.default.fileExists(atPath: urlEquipo.path) else { return }
        guardarEquipo(Equipo.porDefecto)
    }

    func cargarEquipo() -> Equipo {
        var e = Equipo(barra: 20, discos: [], mancuernas: [])
        for c in leerLineas(urlEquipo) where c.count >= 3 {
            let kilos = Double(c[1]) ?? 0
            let cuantos = Int(c[2]) ?? 0
            switch c[0] {
            case "barra":     e.barra = kilos
            case "disco":     e.discos.append(Equipo.Disco(kilos: kilos, cuantos: cuantos))
            case "mancuerna": e.mancuernas.append(kilos)
            default: break
            }
        }
        e.discos.sort { $0.kilos > $1.kilos }
        e.mancuernas.sort(by: >)
        return e
    }

    func guardarEquipo(_ e: Equipo) {
        var lineas = ["que,kilos,cuantos"]
        lineas.append(CSV.linea(["barra", String(format: "%g", e.barra), "1"]))
        for d in e.discos.sorted(by: { $0.kilos > $1.kilos }) {
            lineas.append(CSV.linea(["disco", String(format: "%g", d.kilos), "\(d.cuantos)"]))
        }
        for m in e.mancuernas.sorted(by: >) {
            lineas.append(CSV.linea(["mancuerna", String(format: "%g", m), "1"]))
        }
        escribir(lineas, en: urlEquipo)
    }
}

/// El equipo, guardado y avisando a las pantallas cuando cambia.
final class Fierros: ObservableObject {

    @Published private(set) var equipo: Equipo

    private let sincronizador: Sincronizador

    init(sincronizador: Sincronizador) {
        self.sincronizador = sincronizador
        sincronizador.almacen.prepararEquipo()
        equipo = sincronizador.almacen.cargarEquipo()
    }

    func guardar(_ nuevo: Equipo) {
        equipo = nuevo
        sincronizador.almacen.guardarEquipo(nuevo)
        sincronizador.subirEnSegundoPlano()
    }

    func cambiarBarra(_ kilos: Double) {
        var e = equipo
        e.barra = max(0, kilos)
        guardar(e)
    }

    func agregarDisco(kilos: Double, cuantos: Int) {
        guard kilos > 0, cuantos > 0 else { return }
        var e = equipo
        if let donde = e.discos.firstIndex(where: { abs($0.kilos - kilos) < 0.001 }) {
            e.discos[donde].cuantos += cuantos
        } else {
            e.discos.append(Equipo.Disco(kilos: kilos, cuantos: cuantos))
        }
        e.discos.sort { $0.kilos > $1.kilos }
        guardar(e)
    }

    func quitarDisco(_ disco: Equipo.Disco) {
        var e = equipo
        e.discos.removeAll { abs($0.kilos - disco.kilos) < 0.001 }
        guardar(e)
    }

    func cambiarCantidad(_ disco: Equipo.Disco, a cuantos: Int) {
        var e = equipo
        guard let donde = e.discos.firstIndex(where: { abs($0.kilos - disco.kilos) < 0.001 })
        else { return }
        e.discos[donde].cuantos = max(0, cuantos)
        guardar(e)
    }
}
