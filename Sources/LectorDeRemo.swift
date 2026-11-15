import Foundation
import CoreBluetooth

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

/// Lee la máquina de remo Gadnic por Bluetooth.
///
/// A diferencia de la balanza, acá no hay nada que descifrar: la máquina usa
/// FTMS, el estándar de equipos de gimnasio. Servicio 0x1826, característica
/// 0x2AD1 (Rower Data), con un campo de banderas al principio que dice qué
/// datos vienen en esa trama.
final class LectorDeRemo: NSObject, ObservableObject {

    static let servicio = CBUUID(string: "1826")
    static let canalQueAvisa = CBUUID(string: "2AD1")
    static let nombreQuePublica = "Smart5181"

    @Published var estado = "Arrancando"
    @Published var datos = DatosDeRemo()
    @Published var ultimaTrama = ""
    @Published var cantidadDeTramas = 0
    @Published var nombreDelAparato = ""

    private(set) var tramasCrudas: [String] = []

    private var central: CBCentralManager!
    private var maquina: CBPeripheral?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func buscarDeNuevo() {
        datos = DatosDeRemo()
        if let maquina {
            central.connect(maquina, options: nil)
            estado = "Esperando que la máquina se encienda"
        } else {
            empezarABuscar()
        }
    }

    func textoParaCopiar() -> String {
        var lineas = ["Tramas de la máquina de remo (FTMS 0x2AD1)"]
        lineas.append("Aparato: \(nombreDelAparato)")
        lineas.append("Total: \(tramasCrudas.count)")
        lineas.append("")
        lineas.append(contentsOf: tramasCrudas)
        return lineas.joined(separator: "\n")
    }

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

    private func recibir(_ datosCrudos: Data) {
        let bytes = [UInt8](datosCrudos)
        let enHexa = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        ultimaTrama = enHexa
        tramasCrudas.append(enHexa)
        cantidadDeTramas = tramasCrudas.count

        if let interpretados = Self.interpretar(bytes) {
            datos = interpretados
            estado = "Leyendo"
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
        estado = "En espera. Prendé la máquina y se conecta sola"
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
