import Foundation
import CoreBluetooth

/// Lee la balanza Femmto BWS12 por Bluetooth, detecta cuándo el peso se
/// estabiliza y lo guarda.
///
/// Protocolo: tramas de 20 bytes que empiezan con AC 17 00, con el peso en
/// gramos en los bytes 3, 4 y 5, y una suma de verificación en el byte 19.
final class LectorDeBalanza: NSObject, ObservableObject {

    static let servicio = CBUUID(string: "0000FFB0-0000-1000-8000-00805F9B34FB")
    static let canalQueAvisa = CBUUID(string: "0000FFB2-0000-1000-8000-00805F9B34FB")
    static let nombreQuePublica = "Femmto"

    /// Cuántas veces tiene que repetirse el mismo valor para darlo por estable.
    static let repeticionesParaEstable = 4
    /// Abajo de esto no se guarda: es un objeto o medio pie, no una pesada.
    static let minimoDeCuerpoEnGramos = 30_000
    /// Abajo de esto se considera que la balanza quedó libre.
    static let balanzaLibreEnGramos = 2_000

    @Published var estado = "Arrancando"
    @Published var pesoKg: Double?
    @Published var ultimaTrama = ""
    @Published var tramasDeLaSesion = 0
    @Published var tramasDescartadas = 0
    @Published var pesadas: [Pesada] = []
    @Published var ultimaGuardada: Pesada?
    @Published var estadoDeSalud = "Sin pedir todavía"

    let sincronizador: Sincronizador
    let salud = Salud()

    var almacen: Almacen { sincronizador.almacen }

    private var central: CBCentralManager!
    private var balanza: CBPeripheral?

    private var gramosAnteriores: Int?
    private var repeticiones = 0
    private var yaGuardeEstaSubida = false

    init(sincronizador: Sincronizador) {
        self.sincronizador = sincronizador
        super.init()
        pesadas = almacen.cargarPesadas().sorted { $0.instante > $1.instante }
        ultimaGuardada = pesadas.first
        estadoDeSalud = salud.estadoDelPermiso()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: Lo que puede pedir la pantalla

    func buscarDeNuevo() {
        pesoKg = nil
        reiniciarConteo()
        if let balanza {
            central.connect(balanza, options: nil)
            estado = "Esperando que la balanza se encienda"
        } else {
            empezarABuscar()
        }
    }

    func pedirPermisoDeSalud() {
        salud.pedirPermiso { [weak self] mensaje in
            self?.estadoDeSalud = mensaje
        }
    }

    func mandarASalud(_ pesada: Pesada) {
        salud.guardar(pesada) { [weak self] mensaje in
            self?.estadoDeSalud = mensaje
        }
    }

    func borrar(_ pesada: Pesada) {
        pesadas.removeAll { $0.id == pesada.id }
        almacen.reescribirPesadas(pesadas)
        ultimaGuardada = pesadas.first
    }

    // MARK: Bluetooth

    private func empezarABuscar() {
        guard central.state == .poweredOn else { return }
        estado = "Buscando la balanza"
        // Sin filtrar por servicio: la balanza puede no publicarlo en el aviso.
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    private func reiniciarConteo() {
        gramosAnteriores = nil
        repeticiones = 0
        yaGuardeEstaSubida = false
    }

    // MARK: Interpretar las tramas

    private func interpretar(_ datos: Data) {
        let bytes = [UInt8](datos)
        let enHexa = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        let ahora = Date()

        ultimaTrama = enHexa
        tramasDeLaSesion += 1
        almacen.agregarTrama(enHexa, instante: ahora)

        guard let gramos = pesoEnGramos(de: bytes) else {
            tramasDescartadas += 1
            return
        }

        pesoKg = Double(gramos) / 1000

        // La balanza quedó libre: queda listo para la próxima subida.
        if gramos < Self.balanzaLibreEnGramos {
            yaGuardeEstaSubida = false
            gramosAnteriores = gramos
            repeticiones = 1
            estado = "Escuchando. Subite a la balanza"
            return
        }

        if gramos == gramosAnteriores {
            repeticiones += 1
        } else {
            gramosAnteriores = gramos
            repeticiones = 1
            estado = "Midiendo, todavía se mueve"
        }

        guard repeticiones >= Self.repeticionesParaEstable else { return }

        guard gramos >= Self.minimoDeCuerpoEnGramos else {
            estado = String(format: "Estable en %.2f kg, muy poco para guardar", Double(gramos)/1000)
            return
        }

        guard !yaGuardeEstaSubida else { return }
        yaGuardeEstaSubida = true

        let pesada = Pesada(instante: ahora, gramos: gramos)
        almacen.agregarPesada(pesada)
        pesadas.insert(pesada, at: 0)
        ultimaGuardada = pesada
        estado = "Guardado"
        mandarASalud(pesada)
        sincronizador.subirEnSegundoPlano()
    }

    /// Devuelve los gramos si la trama es válida, y nada si no lo es.
    private func pesoEnGramos(de bytes: [UInt8]) -> Int? {
        guard bytes.count == 20, bytes[0] == 0xAC, bytes[1] == 0x17 else { return nil }

        // Suma de verificación, descifrada el 14/11/2026:
        // byte19 = (byte3 + byte4 + byte5 + byte17 + byte18) mod 32
        let esperada = (Int(bytes[3]) + Int(bytes[4]) + Int(bytes[5])
                        + Int(bytes[17]) + Int(bytes[18])) % 32
        guard esperada == Int(bytes[19]) else { return nil }

        let acarreo = Int(bytes[3]) - 0x68
        guard acarreo >= 0 else { return nil }
        let gramos = acarreo * 65_536 + Int(bytes[4]) * 256 + Int(bytes[5])
        guard gramos >= 0, gramos < 400_000 else { return nil }
        return gramos
    }
}

extension LectorDeBalanza: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:   empezarABuscar()
        case .poweredOff:  estado = "El Bluetooth está apagado"
        case .unauthorized: estado = "Falta el permiso de Bluetooth"
        case .unsupported: estado = "Este aparato no tiene Bluetooth disponible"
        default:           estado = "Preparando el Bluetooth"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let publicado = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name ?? ""
        guard publicado.localizedCaseInsensitiveContains(Self.nombreQuePublica) else { return }

        central.stopScan()
        balanza = peripheral
        peripheral.delegate = self
        estado = "Encontrada. Conectando"
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        tramasDeLaSesion = 0
        tramasDescartadas = 0
        reiniciarConteo()
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
        // La balanza corta sola. El pedido queda pendiente y iOS la reconecta
        // cuando se vuelve a encender, sin tocar nada.
        reiniciarConteo()
        estado = "En espera. Subite y se conecta sola"
        central.connect(peripheral, options: nil)
    }
}

extension LectorDeBalanza: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let servicio = peripheral.services?.first(where: { $0.uuid == Self.servicio }) else {
            estado = "Conectada, pero no apareció el servicio esperado"
            return
        }
        peripheral.discoverCharacteristics([Self.canalQueAvisa], for: servicio)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let canal = service.characteristics?.first(where: { $0.uuid == Self.canalQueAvisa }) else {
            estado = "No apareció el canal de datos"
            return
        }
        peripheral.setNotifyValue(true, for: canal)
        estado = "Escuchando. Subite a la balanza"
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let datos = characteristic.value else { return }
        interpretar(datos)
    }
}
