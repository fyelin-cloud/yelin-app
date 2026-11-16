import SwiftUI

/// Todo lo que no se mira todos los días: la conexión con Drive, los
/// archivos, el estado de los aparatos y la vida de la app.
///
/// Está acá para que las pantallas de Balanza y Remo queden limpias y solo
/// muestren lo que importa en el momento de usarlas.
struct PantallaAjustes: View {
    @ObservedObject var sincronizador: Sincronizador
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var remo: LectorDeRemo

    @State private var estadoDelAviso = "Sin activar"

    private var almacen: Almacen { sincronizador.almacen }

    var body: some View {
        List {
            Section("Google Drive") {
                Fila("Estado", sincronizador.estado)
                if sincronizador.conectado {
                    Button {
                        Task { await sincronizador.subirTodo() }
                    } label: {
                        Label("Subir todo ahora", systemImage: "arrow.up.doc")
                    }
                    Button(role: .destructive) {
                        sincronizador.desconectar()
                    } label: {
                        Label("Desconectar Drive", systemImage: "xmark.circle")
                    }
                } else {
                    Button {
                        sincronizador.conectar()
                    } label: {
                        Label("Conectar con Google Drive", systemImage: "link")
                    }
                }
            }

            Section("Los aparatos") {
                Fila("Balanza", balanza.estado)
                Button {
                    balanza.buscarDeNuevo()
                } label: {
                    Label("Buscar la balanza de nuevo", systemImage: "arrow.clockwise")
                }
                Fila("Remo", remo.estado)
                Button {
                    remo.buscarDeNuevo()
                } label: {
                    Label("Buscar la máquina de nuevo", systemImage: "arrow.clockwise")
                }
            }

            Section("La app") {
                Fila("Versión", Info.version)
                Fila("Firma", Firma.resumen)
                Fila("Aviso de vencimiento", estadoDelAviso)
                Button {
                    Firma.programar { estadoDelAviso = $0 }
                } label: {
                    Label("Avisarme antes de que venza", systemImage: "bell")
                }
            }

            Section {
                NavigationLink {
                    PantallaArchivos(almacen: almacen)
                } label: {
                    Label("Archivos", systemImage: "folder")
                }
                NavigationLink {
                    PantallaTramas(balanza: balanza, remo: remo)
                } label: {
                    Label("Tramas crudas", systemImage: "waveform")
                }
            }

            Section {
                Fila("Permiso", balanza.estadoDeSalud)
                Button {
                    balanza.pedirPermisoDeSalud()
                } label: {
                    Label("Dar permiso a Salud", systemImage: "heart.text.square")
                }
            } header: {
                Text("Salud de Apple")
            } footer: {
                Text("No funciona con la cuenta gratuita de Apple: al instalar, AltStore firma la app sin ese permiso. Queda por si alguna vez pasás a una cuenta paga.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Paleta.fondo)
        .navigationTitle("Ajustes")
        .task { Firma.estadoDelAviso { estadoDelAviso = $0 } }
    }
}

/// Compartir cualquiera de los archivos que escribe la app.
struct PantallaArchivos: View {
    let almacen: Almacen

    var body: some View {
        List {
            Section {
                ShareLink(item: almacen.urlResumen) {
                    Label("Resumen de todo", systemImage: "doc.text")
                }
            } footer: {
                Text("Una página con el estado de todo. Es el que conviene mandar si querés preguntar cómo venís.")
            }

            Section("Peso") {
                Compartir("Pesadas", almacen.urlPesadas)
                Compartir("Tramas de la balanza", almacen.urlTramas)
            }
            Section("Remo") {
                Compartir("Sesiones", almacen.urlSesiones)
                Compartir("Tramas de la máquina", almacen.urlTramasDeRemo)
            }
            Section("Lo que cargás a mano") {
                Compartir("Proteína", almacen.urlConsumo)
                Compartir("Notas", almacen.urlNotas)
                Compartir("Gastos", almacen.urlGastos)
            }
            Section {
                Compartir("Frases de la apertura", almacen.documentos
                    .appendingPathComponent("frases.txt"))
                Compartir("Categorías de gastos", almacen.urlCategorias)
            } footer: {
                Text("Estos dos se pueden editar a mano desde Archivos → En mi iPad → Yelin App.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Paleta.fondo)
        .navigationTitle("Archivos")
    }
}

struct Compartir: View {
    let titulo: String
    let archivo: URL

    init(_ titulo: String, _ archivo: URL) {
        self.titulo = titulo
        self.archivo = archivo
    }

    var body: some View {
        ShareLink(item: archivo) {
            Label(titulo, systemImage: "square.and.arrow.up")
        }
    }
}

/// Lo crudo que mandan los aparatos. Sirve para descifrar y para calibrar.
struct PantallaTramas: View {
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var remo: LectorDeRemo
    @State private var copiado = ""

    var body: some View {
        List {
            Section("Balanza") {
                Fila("Recibidas en esta sesión", "\(balanza.tramasDeLaSesion)")
                Fila("Descartadas", "\(balanza.tramasDescartadas)")
                if !balanza.ultimaTrama.isEmpty {
                    Cruda(balanza.ultimaTrama)
                }
            }

            Section("Remo") {
                Fila("Recibidas en esta sesión", "\(remo.cantidadDeTramas)")
                if !remo.nombreDelAparato.isEmpty {
                    Fila("Aparato", remo.nombreDelAparato)
                }
                if !remo.ultimaTrama.isEmpty {
                    Cruda(remo.ultimaTrama)
                }
                Button {
                    UIPasteboard.general.string = remo.textoParaCopiar()
                    copiado = "remo"
                } label: {
                    Label(copiado == "remo" ? "Copiado" : "Copiar las tramas del remo",
                          systemImage: "doc.on.doc")
                }
                .disabled(remo.cantidadDeTramas == 0)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Paleta.fondo)
        .navigationTitle("Tramas crudas")
    }
}

struct Cruda: View {
    let texto: String

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Última")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(texto)
                .font(.system(.footnote, design: .monospaced))
        }
    }
}
