import Foundation
import UserNotifications

/// Un recordatorio: a qué hora, qué días y de qué.
struct Recordatorio: Identifiable, Equatable {
    let id: String
    var hora: Int
    var minuto: Int
    /// Números de día de la semana como los usa el calendario: 1 es domingo.
    var dias: Set<Int>
    var tipo: Tipo
    var texto: String
    var activo: Bool

    enum Tipo: String, CaseIterable, Identifiable {
        case proteina, pesarse, entrenar, libre
        var id: String { rawValue }

        var nombre: String {
            switch self {
            case .proteina: return "Proteína"
            case .pesarse:  return "Pesarte"
            case .entrenar: return "Entrenar"
            case .libre:    return "Otra cosa"
            }
        }

        var simbolo: String {
            switch self {
            case .proteina: return "cup.and.saucer"
            case .pesarse:  return "scalemass"
            case .entrenar: return "figure.rower"
            case .libre:    return "bell"
            }
        }

        var cuerpoPorDefecto: String {
            switch self {
            case .proteina: return "¿Tomaste el scoop? Lo podés anotar desde acá."
            case .pesarse:  return "Subite a la balanza, mejor siempre a la misma hora."
            case .entrenar: return "Remo o pesas, lo que tengas ganas."
            case .libre:    return ""
            }
        }

        /// Solo el de proteína trae botones para anotar sin abrir la app.
        var categoria: String { self == .proteina ? "proteina" : "simple" }
    }

    static func nuevo(tipo: Tipo = .proteina, hora: Int = 10) -> Recordatorio {
        Recordatorio(id: UUID().uuidString, hora: hora, minuto: 0,
                     dias: [2, 3, 4, 5, 6], tipo: tipo, texto: "", activo: true)
    }

    var horaTexto: String { String(format: "%02d:%02d", hora, minuto) }

    var diasTexto: String {
        if dias.count == 7 { return "Todos los días" }
        if dias == [2, 3, 4, 5, 6] { return "De lunes a viernes" }
        if dias == [1, 7] { return "Fines de semana" }
        if dias.isEmpty { return "Ningún día" }
        return Recordatorio.ordenDeDias
            .filter { dias.contains($0) }
            .map { Fechas.inicialDelDia($0) }
            .joined(separator: " ")
    }

    /// Los días empezando por lunes, que es como los lee una persona acá.
    static let ordenDeDias = [2, 3, 4, 5, 6, 7, 1]

    var titulo: String {
        tipo == .libre && !texto.isEmpty ? texto : tipo.nombre
    }

    var cuerpo: String {
        if tipo == .libre { return texto.isEmpty ? "Recordatorio" : "" }
        return texto.isEmpty ? tipo.cuerpoPorDefecto : texto
    }
}

// MARK: - Dónde se guardan

extension Almacen {

    var urlRecordatorios: URL { documentos.appendingPathComponent("recordatorios.csv") }

    func prepararRecordatorios() {
        crearSiFalta(urlRecordatorios, encabezado: "id,hora,minuto,dias,tipo,texto,activo")
    }

    func cargarRecordatorios() -> [Recordatorio] {
        guard let texto = try? String(contentsOf: urlRecordatorios, encoding: .utf8) else { return [] }
        return texto.split(separator: "\n").dropFirst().compactMap { linea in
            let c = CSV.campos(linea)
            guard c.count >= 7, let hora = Int(c[1]), let minuto = Int(c[2]) else { return nil }
            let dias = Set(c[3].split(separator: "-").compactMap { Int($0) })
            return Recordatorio(id: c[0], hora: hora, minuto: minuto, dias: dias,
                                tipo: Recordatorio.Tipo(rawValue: c[4]) ?? .libre,
                                texto: c[5], activo: c[6] == "si")
        }
    }

    func guardarRecordatorios(_ lista: [Recordatorio]) {
        escribir(["id,hora,minuto,dias,tipo,texto,activo"] + lista.map {
            CSV.linea([$0.id, "\($0.hora)", "\($0.minuto)",
                       $0.dias.sorted().map(String.init).joined(separator: "-"),
                       $0.tipo.rawValue, $0.texto, $0.activo ? "si" : "no"])
        }, en: urlRecordatorios)
    }
}

// MARK: - Los avisos

/// Programa los recordatorios y atiende lo que se toca en la notificación.
///
/// **Lo importante**: el aviso de proteína trae botones para anotar un scoop
/// sin abrir la app. Ese es el punto de toda esta parte: que el dato entre
/// aunque Facundo no abra nada.
final class Avisos: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let compartido = Avisos()

    @Published private(set) var lista: [Recordatorio] = []
    @Published var permiso = "Sin pedir"

    /// Se asigna al arrancar la app. Si está, los scoops entran por acá y la
    /// pantalla se actualiza sola.
    weak var diario: Diario?
    weak var sincronizador: Sincronizador?

    private let centro = UNUserNotificationCenter.current()
    private var almacen: Almacen { sincronizador?.almacen ?? Almacen() }

    private override init() {
        super.init()
    }

    /// Se llama una sola vez, al abrir la app.
    func arrancar(sincronizador: Sincronizador, diario: Diario) {
        self.sincronizador = sincronizador
        self.diario = diario
        sincronizador.almacen.prepararRecordatorios()
        lista = sincronizador.almacen.cargarRecordatorios()
        centro.delegate = self
        registrarCategorias()
        revisarPermiso()
        reprogramar()
    }

    // MARK: Permiso

    func revisarPermiso() {
        centro.getNotificationSettings { [weak self] ajustes in
            DispatchQueue.main.async {
                switch ajustes.authorizationStatus {
                case .authorized, .provisional: self?.permiso = "Activado"
                case .denied:                   self?.permiso = "Rechazado en Configuración"
                default:                        self?.permiso = "Sin activar"
                }
            }
        }
    }

    func pedirPermiso() {
        centro.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] ok, _ in
            DispatchQueue.main.async {
                self?.permiso = ok ? "Activado" : "Permiso rechazado"
                if ok { self?.reprogramar() }
            }
        }
    }

    // MARK: La lista

    func agregar(_ r: Recordatorio) {
        lista.append(r)
        ordenar()
        guardar()
    }

    func reemplazar(_ r: Recordatorio) {
        guard let donde = lista.firstIndex(where: { $0.id == r.id }) else { return }
        lista[donde] = r
        ordenar()
        guardar()
    }

    func borrar(_ r: Recordatorio) {
        lista.removeAll { $0.id == r.id }
        guardar()
    }

    func alternar(_ r: Recordatorio) {
        guard let donde = lista.firstIndex(where: { $0.id == r.id }) else { return }
        lista[donde].activo.toggle()
        guardar()
    }

    private func ordenar() {
        lista.sort { ($0.hora, $0.minuto) < ($1.hora, $1.minuto) }
    }

    private func guardar() {
        almacen.guardarRecordatorios(lista)
        reprogramar()
        sincronizador?.subirEnSegundoPlano()
    }

    // MARK: Programar

    /// Borra todo lo que había programado y lo vuelve a armar. Una
    /// notificación por recordatorio y por día de la semana.
    func reprogramar() {
        // Se saca la copia acá, en el hilo principal: la respuesta del sistema
        // llega en otro hilo y no conviene leer la lista desde ahí.
        let activos = lista.filter { $0.activo }
        centro.getPendingNotificationRequests { [weak self] pendientes in
            guard let self else { return }
            let mios = pendientes.map(\.identifier).filter { $0.hasPrefix("rec-") }
            self.centro.removePendingNotificationRequests(withIdentifiers: mios)

            for r in activos {
                for dia in r.dias {
                    let contenido = UNMutableNotificationContent()
                    contenido.title = r.titulo
                    contenido.body = r.cuerpo
                    contenido.sound = .default
                    contenido.categoryIdentifier = r.tipo.categoria
                    contenido.userInfo = ["tipo": r.tipo.rawValue]

                    var partes = DateComponents()
                    partes.hour = r.hora
                    partes.minute = r.minuto
                    partes.weekday = dia

                    let cuando = UNCalendarNotificationTrigger(dateMatching: partes, repeats: true)
                    self.centro.add(UNNotificationRequest(identifier: "rec-\(r.id)-\(dia)",
                                                          content: contenido, trigger: cuando))
                }
            }
        }
    }

    private func registrarCategorias() {
        let unScoop = UNNotificationAction(identifier: "scoop-1",
                                           title: "Anotar 1 scoop", options: [])
        let medio = UNNotificationAction(identifier: "scoop-05",
                                         title: "Anotar ½", options: [])
        let despues = UNNotificationAction(identifier: "posponer",
                                           title: "En 30 minutos", options: [])
        let listo = UNNotificationAction(identifier: "listo",
                                         title: "Listo", options: [])

        let proteina = UNNotificationCategory(identifier: "proteina",
                                              actions: [unScoop, medio, despues],
                                              intentIdentifiers: [])
        let simple = UNNotificationCategory(identifier: "simple",
                                            actions: [listo, despues],
                                            intentIdentifiers: [])
        centro.setNotificationCategories([proteina, simple])
    }

    // MARK: Qué pasa cuando se toca

    func userNotificationCenter(_ centro: UNUserNotificationCenter,
                                willPresent notificacion: UNNotification,
                                withCompletionHandler listo: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Que el aviso se vea también con la app abierta.
        listo([.banner, .sound, .list])
    }

    func userNotificationCenter(_ centro: UNUserNotificationCenter,
                                didReceive respuesta: UNNotificationResponse,
                                withCompletionHandler listo: @escaping () -> Void) {
        switch respuesta.actionIdentifier {
        case "scoop-1":  anotarScoops(1)
        case "scoop-05": anotarScoops(0.5)
        case "posponer": posponer(respuesta.notification)
        default:         break
        }
        listo()
    }

    /// Anota el scoop. Si la app está abierta pasa por el diario y la pantalla
    /// se actualiza sola; si no, se escribe derecho en el archivo.
    private func anotarScoops(_ cuantos: Double) {
        if let diario {
            DispatchQueue.main.async { diario.anotarScoops(cuantos) }
            return
        }
        let suelto = Almacen()
        suelto.agregarConsumo(Consumo(instante: Date(), cantidad: cuantos, que: "proteína"))
    }

    private func posponer(_ notificacion: UNNotification) {
        let viejo = notificacion.request.content
        let contenido = UNMutableNotificationContent()
        contenido.title = viejo.title
        contenido.body = viejo.body
        contenido.sound = .default
        contenido.categoryIdentifier = viejo.categoryIdentifier
        contenido.userInfo = viejo.userInfo

        let cuando = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 60, repeats: false)
        centro.add(UNNotificationRequest(identifier: "rec-pospuesto-\(UUID().uuidString)",
                                         content: contenido, trigger: cuando))
    }
}
