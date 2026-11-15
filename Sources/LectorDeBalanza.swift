import Foundation
import CoreBluetooth

/// Lee la balanza Femmto BWS12 por Bluetooth.
///
/// La balanza usa un protocolo propio: manda tramas de 20 bytes que empiezan
/// con AC 17 00 y llevan el peso en gramos en los bytes 3, 4 y 5.
final class LectorDeBalanza: NSObject, ObservableObject {

    // Identificadores de la balanza, ya descifrados.
    static let servicio = CBUUID(string: "0000FFB0-0000-1000-8000-00805F9B34FB")
    static let canalQueAvisa = CBUUID(string: "0000FFB2-0000-1000-8000-00805F9B34FB")
    static let nombreQuePublica = "Femmto"

    @Published var estado = "Arrancando"
    @Published var pesoKg: Double?
    @Published var ultimaTrama = ""
    @Published var cantidadDeTramas = 0
    @Published var bluetoothListo = false

    /// Todas las tramas recibidas, para poder copiarlas y analizarlas después.
    private(set) var tramasCrudas: [String] = []

    private var central: CBCentralManager!
    private var balanza: CBPeripheral?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func buscarDeNuevo() {
        pesoKg = nil
        if let balanza {
            central.connect(balanza, options: nil)
            estado = "Esperando que la balanza se encienda"
        } else {
            empezarABuscar()
        }
    }

    func textoParaCopiar() -> String {
        var lineas = ["Tramas de la balanza Femmto BWS12"]
        lineas.append("Total: \(tramasCrudas.count)")
        lineas.append("")
        lineas.append(contentsOf: tramasCrudas)
        return lineas.joined(separator: "\n")
    }

    private func empezarABuscar() {
        guard central.state == .poweredOn else { return }
        estado = "Buscando la balanza"
        // Se busca sin filtrar por servicio porque la balanza puede no
        // publicarlo en el aviso; se la reconoce por el nombre.
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    private func interpretar(_ datos: Data) {
        let bytes = [UInt8](datos)

        let enHexa = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        ultimaTrama = enHexa
        tramasCrudas.append(enHexa)
        cantidadDeTramas = tramasCrudas.count

        guard bytes.count >= 6, bytes[0] == 0xAC, bytes[1] == 0x17 else { return }

        let acarreo = Int(bytes[3]) - 0x68
        guard acarreo >= 0 else { return }
        let gramos = acarreo * 65_536 + Int(bytes[4]) * 256 + Int(bytes[5])
        guard gramos >= 0, gramos < 400_000 else { return }

        pesoKg = Double(gramos) / 1000.0
        estado = "Leyendo"
    }
}

extension LectorDeBalanza: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            bluetoothListo = true
            empezarABuscar()
        case .poweredOff:
            bluetoothListo = false
            estado = "El Bluetooth está apagado"
        case .unauthorized:
            bluetoothListo = false
            estado = "Falta el permiso de Bluetooth"
        case .unsupported:
            bluetoothListo = false
            estado = "Este aparato no tiene Bluetooth disponible"
        default:
            bluetoothListo = false
            estado = "Preparando el Bluetooth"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let publicado = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? ""
        guard publicado.localizedCaseInsensitiveContains(Self.nombreQuePublica) else { return }

        central.stopScan()
        balanza = peripheral
        peripheral.delegate = self
        estado = "Encontrada: \(publicado). Conectando"
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        estado = "Conectada. Buscando el canal de datos"
        peripheral.discoverServices([Self.servicio])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        estado = "No se pudo conectar. Reintentando"
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        // La balanza corta sola a los pocos segundos. El pedido de conexión
        // queda pendiente y iOS la reconecta cuando se vuelve a encender.
        estado = "Se desconectó. Subite de nuevo y vuelve sola"
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
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let canal = service.characteristics?.first(where: { $0.uuid == Self.canalQueAvisa }) else {
            estado = "No apareció el canal de datos"
            return
        }
        peripheral.setNotifyValue(true, for: canal)
        estado = "Escuchando. Subite a la balanza"
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let datos = characteristic.value else { return }
        interpretar(datos)
    }
}
