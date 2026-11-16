import Foundation

/// Lo que comparten la balanza y el remo: dónde se guardan los datos y cómo
/// suben a Drive. Existe una sola instancia, creada al abrir la app.
final class Sincronizador: ObservableObject {

    let almacen = Almacen()
    let drive = Drive()

    @Published var estado = "Sin conectar"
    @Published var conectado = false

    init() {
        revisar()
    }

    func revisar() {
        guard drive.estaConfigurado else {
            conectado = false
            estado = "La app se compiló sin el identificador de Google"
            return
        }
        conectado = drive.haySesion
        estado = conectado ? "Conectado" : "Sin conectar"
    }

    func conectar() {
        estado = "Abriendo el inicio de sesión de Google"
        Task { @MainActor in
            do {
                try await drive.iniciarSesion()
                conectado = true
                estado = "Conectado"
                await subirTodo()
            } catch {
                conectado = false
                estado = "No se pudo conectar: \(error.localizedDescription)"
            }
        }
    }

    func desconectar() {
        drive.cerrarSesion()
        conectado = false
        estado = "Sin conectar"
    }

    @MainActor
    func subirTodo() async {
        guard drive.estaConfigurado, drive.haySesion else { return }
        estado = "Subiendo"
        almacen.escribirResumen(Resumen.generar(almacen: almacen))
        almacen.escribirPanel(Panel.generar(almacen: almacen))
        do {
            try await drive.subir(almacen.archivosParaSubir)
            estado = "Subido a las " + Date().formatted(date: .omitted, time: .shortened)
        } catch {
            estado = "Falló la subida: \(error.localizedDescription)"
        }
    }

    /// Para llamar desde código que no es asincrónico.
    func subirEnSegundoPlano() {
        Task { @MainActor in await subirTodo() }
    }
}
