import Foundation
import CoreBluetooth
import UIKit

/// Lo que manda la máquina de remo en cada aviso.
struct DatosDeRemo {
    var paladasPorMinuto: Double?
    var paladasTotales: Int?
    var distanciaMetros: Int?
    var ritmoPor500: Int?
    var ritmoPromedioPor500: Int?
    var watts: Int?
    var wattsPromedio: Int?
    var calorias: Int?
    var pulso: Int?
    var tiempoSegundos: Int?
}

/// Lee la máquina de remo Gadnic por Bluetooth y guarda cada sesión.
///
/// La máquina usa FTMS, el estándar de equipos de gimnasio: servicio 0x1826,
/// característica 0x2AD1. Pero solo manda cuatro cosas —paladas, conteo, ritmo
/// y watts del momento— y borra todo al apagarse. La distancia, el tiempo y el
/// historial los hace la app. Detalle en `claude/remo-ftms.md`.
final class LectorDeRemo: NSObject, ObservableObject {

    static let servicio = CBUUID(string: "1826")
    static let canalQueAvisa = CBUUID(string: "2AD1")
    static let nombreQuePublica = "Smart5181"

    /// Sin remar durante este tiempo, la sesión se da por terminada.
    static let segundosParaCerrarSesion = 90.0
    /// Abajo de esto no se guarda: fue una prueba, no una sesión.
    static let metrosMinimosParaGuardar = 50.0

    @Published var estado = "Arrancando"
    @Published var datos = DatosDeRemo()
    @Published var ultimaTrama = ""
    @Published var cantidadDeTramas = 0
    @Published var nombreDelAparato = ""

    /// La máquina no manda distancia ni tiempo: los calcula la app.
    @Published var distanciaCalculada = 0.0
    @Published var segundosRemando = 0.0
    @Published var segundosTotales = 0.0
    @Published var wattsPromedioCalculado = 0.0
    @Published var paladasDeLaSesion = 0

    /// Si avisa por voz cada 500 metros. Se recuerda entre sesiones.
    @Published var avisosPorVoz = UserDefaults.standard.bool(forKey: "avisosPorVoz") {
        didSet {
            UserDefaults.standard.set(avisosPorVoz, forKey: "avisosPorVoz")
            if !avisosPorVoz { Voz.callar() }
        }
    }

    @Published var sesionAbierta = false
    @Published var sesiones: [SesionDeRemo] = []
    @Published var avisoDeRecuperacion = ""

    let sincronizador: Sincronizador
    var almacen: Almacen { sincronizador.almacen }

    private var central: CBCentralManager!
    private var maquina: CBPeripheral?

    private var inicioDeSesion: Date?
    private var instanteAnterior: Date?
    private var ultimoRemo: Date?
    private var sumaDeWattsPorSegundo = 0.0
    /// Cuánto marcaba el contador acumulado de la máquina al abrir la sesión.
    private var paladasAlAbrir: Int?
    /// A qué distancia toca el próximo aviso por voz.
    private var proximoAviso = 500.0

    private(set) var tramasCrudas: [String] = []
    private var tramasPendientes: [(instante: Date, trama: String)] = []
    private var ultimoGuardadoEnCurso = Date.distantPast

    init(sincronizador: Sincronizador) {
        self.sincronizador = sincronizador
        super.init()
        sesiones = almacen.cargarSesiones().sorted { $0.inicio > $1.inicio }
        recuperarSesionInterrumpida()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: Lo que puede pedir la pantalla

    func buscarDeNuevo() {
        if let maquina {
            central.connect(maquina, options: nil)
            estado = "Esperando que la máquina se encienda"
        } else {
            empezarABuscar()
        }
    }

    func terminarSesion() {
        cerrarSesion(motivo: "a mano")
    }

    func descartarSesion() {
        inicioDeSesion = nil
        sesionAbierta = false
        almacen.borrarEnCurso()
        reiniciarAcumuladores()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func borrar(_ sesion: SesionDeRemo) {
        sesiones.removeAll { $0.id == sesion.id }
        almacen.reescribirSesiones(sesiones)
        sincronizador.subirEnSegundoPlano()
    }

    func textoParaCopiar() -> String {
        var lineas = ["Tramas de la máquina de remo (FTMS 0x2AD1)"]
        lineas.append("Aparato: \(nombreDelAparato)")
        lineas.append("Total: \(tramasCrudas.count)")
        lineas.append("")
        lineas.append(contentsOf: tramasCrudas)
        return lineas.joined(separator: "\n")
    }

    // MARK: Sesiones

    private func volcarTramas() {
        let pendientes = tramasPendientes
        tramasPendientes.removeAll()
        almacen.agregarTramasDeRemo(pendientes)
    }

    private func reiniciarAcumuladores() {
        distanciaCalculada = 0
        segundosRemando = 0
        segundosTotales = 0
        wattsPromedioCalculado = 0
        paladasDeLaSesion = 0
        paladasAlAbrir = nil
        proximoAviso = 500
        sumaDeWattsPorSegundo = 0
        instanteAnterior = nil
        ultimoRemo = nil
        datos = DatosDeRemo()
    }

    private func sesionActual(hasta fin: Date) -> SesionDeRemo? {
        guard let inicio = inicioDeSesion else { return nil }
        return SesionDeRemo(
            inicio: inicio,
            fin: fin,
            segundosRemando: segundosRemando,
            segundosTotales: segundosTotales,
            metros: distanciaCalculada,
            paladas: paladasDeLaSesion,
            wattsPromedio: wattsPromedioCalculado)
    }

    private func abrirSesion(_ ahora: Date, conteo: Int?) {
        inicioDeSesion = ahora
        sesionAbierta = true
        avisoDeRecuperacion = ""
        estado = "Sesión en curso"
        paladasAlAbrir = conteo
        proximoAviso = 500
        // Mientras se rema, la pantalla no se apaga: si el iPad se duerme,
        // iOS corta la entrega de tramas y la sesión queda trunca.
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Cuántas paladas van en **esta** sesión.
    ///
    /// La máquina manda un contador acumulado que **no se reinicia** cuando se
    /// resetea el display: sigue contando desde que se encendió. Por eso hay
    /// que guardar cuánto marcaba al abrir la sesión y restar.
    ///
    /// Comprobado el 21/11/2026: el display marcaba 20 paladas y la app 26, y
    /// otra vez 70 contra 76.
    private func contarPaladas(_ d: DatosDeRemo) {
        guard let conteo = d.paladasTotales else { return }
        if paladasAlAbrir == nil { paladasAlAbrir = conteo }
        // Si la máquina se apagó y volvió, el contador arranca de cero otra
        // vez: en ese caso se toma el valor nuevo como la nueva base.
        if let base = paladasAlAbrir, conteo < base { paladasAlAbrir = conteo }
        let enLaSesion = conteo - (paladasAlAbrir ?? conteo)
        if enLaSesion > paladasDeLaSesion { paladasDeLaSesion = enLaSesion }
    }

    private func cerrarSesion(motivo: String) {
        volcarTramas()
        UIApplication.shared.isIdleTimerDisabled = false
        guard let sesion = sesionActual(hasta: Date()) else { return }
        inicioDeSesion = nil
        sesionAbierta = false
        almacen.borrarEnCurso()

        if sesion.metros >= Self.metrosMinimosParaGuardar {
            almacen.agregarSesion(sesion)
            sesiones.insert(sesion, at: 0)
            estado = String(format: "Sesión guardada: %.0f m (%@)", sesion.metros, motivo)
            sincronizador.subirEnSegundoPlano()
        } else {
            estado = "Sesión demasiado corta, no se guardó"
        }
        reiniciarAcumuladores()
    }

    /// Si la app se cerró o se cortó el Bluetooth a mitad de una sesión, queda
    /// anotada en disco. Al abrir de nuevo se rescata en vez de perderse.
    private func recuperarSesionInterrumpida() {
        guard let interrumpida = almacen.leerEnCurso() else { return }
        almacen.borrarEnCurso()
        guard interrumpida.metros >= Self.metrosMinimosParaGuardar else { return }
        almacen.agregarSesion(interrumpida)
        sesiones.insert(interrumpida, at: 0)
        sesiones.sort { $0.inicio > $1.inicio }
        avisoDeRecuperacion = String(format: "Se recuperó una sesión interrumpida de %.0f m",
                                     interrumpida.metros)
        sincronizador.subirEnSegundoPlano()
    }

    // MARK: Bluetooth

    private func empezarABuscar() {
        guard central.state == .poweredOn else { return }
        estado = "Buscando la máquina de remo"
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    // MARK: Interpretar FTMS

    static func interpretar(_ bytes: [UInt8]) -> DatosDeRemo? {
        guard bytes.count >= 2 else { return nil }
        let banderas = Int(bytes[0]) | (Int(bytes[1]) << 8)
        var i = 2
        var d = DatosDeRemo()

        func u8() -> Int? {
            guard i < bytes.count else { return nil }
            let v = Int(bytes[i]); i += 1; return v
        }
        func u16() -> Int? {
            guard i + 1 < bytes.count else { return nil }
            let v = Int(bytes[i]) | (Int(bytes[i + 1]) << 8); i += 2; return v
        }
        func s16() -> Int? {
            guard let v = u16() else { return nil }
            return v > 32_767 ? v - 65_536 : v
        }
        func u24() -> Int? {
            guard i + 2 < bytes.count else { return nil }
            let v = Int(bytes[i]) | (Int(bytes[i + 1]) << 8) | (Int(bytes[i + 2]) << 16)
            i += 3; return v
        }

        // Bandera 0 invertida: si está en cero, vienen paladas y conteo.
        if banderas & 0x0001 == 0 {
            if let r = u8() { d.paladasPorMinuto = Double(r) / 2 }
            d.paladasTotales = u16()
        }
        if banderas & 0x0002 != 0 { _ = u8() }                      // paladas promedio
        if banderas & 0x0004 != 0 { d.distanciaMetros = u24() }
        if banderas & 0x0008 != 0 { d.ritmoPor500 = u16() }
        if banderas & 0x0010 != 0 { d.ritmoPromedioPor500 = u16() }
        if banderas & 0x0020 != 0 { d.watts = s16() }
        if banderas & 0x0040 != 0 { d.wattsPromedio = s16() }
        if banderas & 0x0080 != 0 { _ = s16() }                     // nivel de resistencia
        if banderas & 0x0100 != 0 {
            d.calorias = u16()
            _ = u16()                                               // calorías por hora
            _ = u8()                                                // calorías por minuto
        }
        if banderas & 0x0200 != 0 { d.pulso = u8() }
        if banderas & 0x0400 != 0 { _ = u8() }                      // equivalente metabólico
        if banderas & 0x0800 != 0 { d.tiempoSegundos = u16() }
        if banderas & 0x1000 != 0 { _ = u16() }                     // tiempo restante

        return d
    }

    /// La máquina solo manda ritmo y potencia del momento. La distancia y el
    /// tiempo se calculan acá: a un ritmo de X segundos cada 500 m, la
    /// velocidad es 500/X metros por segundo.
    private func acumular(_ d: DatosDeRemo, ahora: Date) {
        defer { instanteAnterior = ahora }
        guard let anterior = instanteAnterior else { return }

        let transcurrido = ahora.timeIntervalSince(anterior)
        guard transcurrido > 0, transcurrido < 5 else { return }

        let remando = (d.ritmoPor500 ?? 0) > 0

        if remando {
            if inicioDeSesion == nil { abrirSesion(ahora, conteo: d.paladasTotales) }
            ultimoRemo = ahora
        }

        guard inicioDeSesion != nil else { return }

        contarPaladas(d)
        segundosTotales += transcurrido

        if remando, let ritmo = d.ritmoPor500 {
            segundosRemando += transcurrido
            distanciaCalculada += (500.0 / Double(ritmo)) * transcurrido
            if let w = d.watts, w > 0 {
                sumaDeWattsPorSegundo += Double(w) * transcurrido
                wattsPromedioCalculado = sumaDeWattsPorSegundo / max(segundosRemando, 1)
            }
            avisarSiCorresponde(ritmo)
        }

        // Se anota cada cinco segundos, no en cada trama: alcanza para no
        // perder nada que importe si la app se cierra de golpe.
        if ahora.timeIntervalSince(ultimoGuardadoEnCurso) > 5,
           let sesion = sesionActual(hasta: ahora) {
            ultimoGuardadoEnCurso = ahora
            almacen.guardarEnCurso(sesion)
        }

        if let ultimo = ultimoRemo,
           ahora.timeIntervalSince(ultimo) > Self.segundosParaCerrarSesion {
            cerrarSesion(motivo: "sin remar")
        }
    }

    /// El aviso hablado de cada 500 metros.
    ///
    /// Solo suena con la app abierta: para hablar con la pantalla apagada
    /// haría falta el permiso de audio en segundo plano, que obliga a tener
    /// algo sonando todo el tiempo y haría que iOS cierre la app.
    private func avisarSiCorresponde(_ ritmo: Int) {
        guard avisosPorVoz, distanciaCalculada >= proximoAviso else { return }
        let marca = Int(proximoAviso)
        proximoAviso += 500
        Voz.decir("\(marca) metros. Ritmo \(Voz.ritmoHablado(ritmo)) por 500.")
    }

    private func recibir(_ datosCrudos: Data) {
        let bytes = [UInt8](datosCrudos)
        let enHexa = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        let ahora = Date()

        ultimaTrama = enHexa
        tramasCrudas.append(enHexa)
        cantidadDeTramas = tramasCrudas.count

        tramasPendientes.append((ahora, enHexa))
        if tramasPendientes.count >= 25 { volcarTramas() }

        if let interpretados = Self.interpretar(bytes) {
            datos = interpretados
            acumular(interpretados, ahora: ahora)
            if !sesionAbierta { estado = "Escuchando. Dale unas paladas" }
        }
    }
}

extension LectorDeRemo: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:    empezarABuscar()
        case .poweredOff:   estado = "El Bluetooth está apagado"
        case .unauthorized: estado = "Falta el permiso de Bluetooth"
        case .unsupported:  estado = "Este aparato no tiene Bluetooth disponible"
        default:            estado = "Preparando el Bluetooth"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let publicado = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name ?? ""
        let serviciosPublicados = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []

        let esElRemo = publicado.localizedCaseInsensitiveContains(Self.nombreQuePublica)
            || serviciosPublicados.contains(Self.servicio)
        guard esElRemo else { return }

        central.stopScan()
        maquina = peripheral
        nombreDelAparato = publicado.isEmpty ? "sin nombre" : publicado
        peripheral.delegate = self
        estado = "Encontrada. Conectando"
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        cantidadDeTramas = 0
        tramasCrudas.removeAll()
        reiniciarAcumuladores()
        estado = "Conectada. Buscando el canal de datos"
        peripheral.discoverServices([Self.servicio])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral, error: Error?) {
        estado = "No se pudo conectar. Reintentando"
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if sesionAbierta {
            cerrarSesion(motivo: "se cortó la conexión")
        } else {
            volcarTramas()
            estado = "En espera. Prendé la máquina y se conecta sola"
        }
        central.connect(peripheral, options: nil)
    }
}

extension LectorDeRemo: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let servicio = peripheral.services?.first(where: { $0.uuid == Self.servicio }) else {
            estado = "Conectada, pero no apareció el servicio de gimnasio"
            return
        }
        peripheral.discoverCharacteristics([Self.canalQueAvisa], for: servicio)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let canal = service.characteristics?.first(where: { $0.uuid == Self.canalQueAvisa }) else {
            estado = "No apareció el canal de datos de remo"
            return
        }
        peripheral.setNotifyValue(true, for: canal)
        estado = "Escuchando. Dale unas paladas"
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let valor = characteristic.value else { return }
        recibir(valor)
    }
}
