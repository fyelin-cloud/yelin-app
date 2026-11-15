import Foundation

/// Lo que Facundo carga a mano: proteína, notas y gastos.
///
/// Igual que el resto, cada cambio se guarda en su CSV y dispara la subida a
/// Drive. No hay botón de guardar en ningún lado.
final class Diario: ObservableObject {

    @Published private(set) var consumo: [Consumo] = []
    @Published private(set) var notas: [Nota] = []
    @Published private(set) var gastos: [Gasto] = []

    let sincronizador: Sincronizador
    private var almacen: Almacen { sincronizador.almacen }

    init(sincronizador: Sincronizador) {
        self.sincronizador = sincronizador
        consumo = almacen.cargarConsumo().sorted { $0.instante > $1.instante }
        notas = almacen.cargarNotas().sorted { $0.instante > $1.instante }
        gastos = almacen.cargarGastos().sorted { $0.instante > $1.instante }
    }

    private func subir() { sincronizador.subirEnSegundoPlano() }

    // MARK: Proteína

    var scoopsDeHoy: Double {
        consumo
            .filter { Calendar.current.isDateInToday($0.instante) }
            .reduce(0) { $0 + $1.cantidad }
    }

    var consumoDeHoy: [Consumo] {
        consumo.filter { Calendar.current.isDateInToday($0.instante) }
    }

    func anotarScoops(_ cuantos: Double) {
        let nuevo = Consumo(instante: Date(), cantidad: cuantos, que: "proteína")
        almacen.agregarConsumo(nuevo)
        consumo.insert(nuevo, at: 0)
        subir()
    }

    func borrar(_ c: Consumo) {
        consumo.removeAll { $0.id == c.id }
        almacen.reescribirConsumo(consumo)
        subir()
    }

    /// Total por día, del más nuevo al más viejo.
    func consumoPorDia(ultimos dias: Int = 14) -> [(dia: Date, total: Double)] {
        let calendario = Calendar.current
        var sumas: [Date: Double] = [:]
        for c in consumo {
            let dia = calendario.startOfDay(for: c.instante)
            sumas[dia, default: 0] += c.cantidad
        }
        return sumas.map { (dia: $0.key, total: $0.value) }
            .sorted { $0.dia > $1.dia }
            .prefix(dias)
            .map { $0 }
    }

    // MARK: Notas

    func guardarNota(texto: String, importante: Bool) {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return }
        let nueva = Nota(instante: Date(), texto: limpio, importante: importante)
        notas.insert(nueva, at: 0)
        ordenarNotas()
        almacen.reescribirNotas(notas)
        subir()
    }

    func reemplazar(_ nota: Nota, texto: String, importante: Bool) {
        guard let donde = notas.firstIndex(where: { $0.id == nota.id }) else { return }
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return }
        notas[donde].texto = limpio
        notas[donde].importante = importante
        ordenarNotas()
        almacen.reescribirNotas(notas)
        subir()
    }

    func borrar(_ n: Nota) {
        notas.removeAll { $0.id == n.id }
        almacen.reescribirNotas(notas)
        subir()
    }

    /// Las importantes arriba, y dentro de cada grupo las más nuevas primero.
    private func ordenarNotas() {
        notas.sort {
            if $0.importante != $1.importante { return $0.importante }
            return $0.instante > $1.instante
        }
    }

    func notasQueCoinciden(con busqueda: String) -> [Nota] {
        let texto = busqueda.trimmingCharacters(in: .whitespaces)
        guard !texto.isEmpty else { return notas }
        return notas.filter { $0.texto.localizedCaseInsensitiveContains(texto) }
    }

    // MARK: Gastos

    var categorias: [String] { almacen.categorias() }

    func anotarGasto(monto: Double, categoria: String, detalle: String) {
        guard monto > 0 else { return }
        let nuevo = Gasto(instante: Date(), monto: monto, categoria: categoria,
                          detalle: detalle.trimmingCharacters(in: .whitespaces))
        almacen.agregarGasto(nuevo)
        gastos.insert(nuevo, at: 0)
        subir()
    }

    func borrar(_ g: Gasto) {
        gastos.removeAll { $0.id == g.id }
        almacen.reescribirGastos(gastos)
        subir()
    }

    func gastosDelMes(corrido atras: Int = 0) -> [Gasto] {
        let calendario = Calendar.current
        guard let base = calendario.date(byAdding: .month, value: -atras, to: Date()) else { return [] }
        let mes = calendario.component(.month, from: base)
        let anio = calendario.component(.year, from: base)
        return gastos.filter {
            calendario.component(.month, from: $0.instante) == mes
                && calendario.component(.year, from: $0.instante) == anio
        }
    }

    func totalDelMes(corrido atras: Int = 0) -> Double {
        gastosDelMes(corrido: atras).reduce(0) { $0 + $1.monto }
    }

    /// Cuánto se gastó en cada categoría este mes y el anterior.
    func porCategoria() -> [(categoria: String, esteMes: Double, mesPasado: Double)] {
        var ahora: [String: Double] = [:]
        var antes: [String: Double] = [:]
        for g in gastosDelMes() { ahora[g.categoria, default: 0] += g.monto }
        for g in gastosDelMes(corrido: 1) { antes[g.categoria, default: 0] += g.monto }
        let todas = Set(ahora.keys).union(antes.keys)
        return todas
            .map { (categoria: $0, esteMes: ahora[$0] ?? 0, mesPasado: antes[$0] ?? 0) }
            .sorted { $0.esteMes > $1.esteMes }
    }
}
