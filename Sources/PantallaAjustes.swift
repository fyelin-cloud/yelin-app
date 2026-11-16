import SwiftUI
import UIKit

/// Todo lo que no se mira todos los días: la conexión con Drive, los
/// archivos, el estado de los aparatos y la vida de la app.
///
/// Está acá para que las pantallas de datos queden limpias y solo muestren
/// lo que importa en el momento de usarlas.
struct PantallaAjustes: View {
    @ObservedObject var sincronizador: Sincronizador
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var remo: LectorDeRemo
    @ObservedObject var pesas: Pesas
    @ObservedObject var metas: Metas

    @State private var estadoDelAviso = "Sin activar"

    private var almacen: Almacen { sincronizador.almacen }

    var body: some View {
        Pantalla(titulo: "Ajustes") {
            Bloque(titulo: "Google Drive",
                   pie: "Cada cosa que anotás se sube sola. No hay botón de guardar.") {
                Fila("Estado", sincronizador.estado)
                Linea()
                if sincronizador.conectado {
                    Accion(texto: "Subir todo ahora", simbolo: "arrow.up.doc") {
                        Task { await sincronizador.subirTodo() }
                    }
                    Linea()
                    Accion(texto: "Desconectar Drive", simbolo: "xmark.circle",
                           destructiva: true) {
                        sincronizador.desconectar()
                    }
                } else {
                    Accion(texto: "Conectar con Google Drive", simbolo: "link") {
                        sincronizador.conectar()
                    }
                }
            }

            Bloque(titulo: "Los aparatos") {
                Fila("Balanza", balanza.estado)
                Linea()
                Accion(texto: "Buscar la balanza de nuevo", simbolo: "arrow.clockwise") {
                    balanza.buscarDeNuevo()
                }
                Linea()
                Fila("Remo", remo.estado)
                Linea()
                Accion(texto: "Buscar la máquina de nuevo", simbolo: "arrow.clockwise") {
                    remo.buscarDeNuevo()
                }
            }

            Bloque(titulo: "Lo que hay guardado") {
                Fila("Pesadas", "\(balanza.pesadas.count)")
                Linea()
                Fila("Sesiones de remo", "\(remo.sesiones.count)")
                Linea()
                Fila("Series de pesas", "\(pesas.series.count)")
            }

            Bloque(titulo: "La app") {
                Fila("Versión", Info.version)
                Linea()
                Fila("Firma", Firma.resumen)
                Linea()
                Fila("Aviso de vencimiento", estadoDelAviso)
                Linea()
                Accion(texto: "Avisarme antes de que venza", simbolo: "bell") {
                    Firma.programar { estadoDelAviso = $0 }
                }
            }

            Bloque {
                Navega(texto: "Objetivos", simbolo: "target",
                       detalle: metas.objetivos.hayAlguno
                              ? "\(metas.objetivos.cuantos)" : "Ninguno") {
                    PantallaObjetivos(metas: metas)
                }
                Linea()
                Navega(texto: "Recordatorios", simbolo: "bell",
                       detalle: Avisos.compartido.lista.isEmpty ? "Ninguno"
                              : "\(Avisos.compartido.lista.count)") {
                    PantallaRecordatorios()
                }
                Linea()
                Navega(texto: "Archivos", simbolo: "folder") {
                    PantallaArchivos(almacen: almacen)
                }
                Linea()
                Navega(texto: "Tramas crudas", simbolo: "waveform") {
                    PantallaTramas(balanza: balanza, remo: remo)
                }
            }

            Bloque(titulo: "Salud de Apple",
                   pie: "No funciona con la cuenta gratuita de Apple: al instalar, "
                      + "AltStore firma la app sin ese permiso. Queda por si alguna vez "
                      + "pasás a una cuenta paga.") {
                Fila("Permiso", balanza.estadoDeSalud)
                Linea()
                Accion(texto: "Dar permiso a Salud", simbolo: "heart.text.square") {
                    balanza.pedirPermisoDeSalud()
                }
            }
        }
        .task { Firma.estadoDelAviso { estadoDelAviso = $0 } }
    }
}

/// Compartir cualquiera de los archivos que escribe la app.
struct PantallaArchivos: View {
    let almacen: Almacen

    var body: some View {
        Pantalla(titulo: "Archivos",
                 bajada: "Todo en texto plano, legible sin la app") {
            Bloque(titulo: "Para mirar",
                   pie: "El panel se abre con doble clic en la computadora y muestra "
                      + "todo con sus gráficos, sin internet. El resumen es el que "
                      + "conviene mandar si querés preguntar cómo venís.") {
                Compartir("Panel para la PC", almacen.urlPanel)
                Linea()
                Compartir("Resumen de todo", almacen.urlResumen)
            }

            Bloque(titulo: "Peso") {
                Compartir("Pesadas", almacen.urlPesadas)
                Linea()
                Compartir("Tramas de la balanza", almacen.urlTramas)
            }

            Bloque(titulo: "Entrenamiento") {
                Compartir("Sesiones de remo", almacen.urlSesiones)
                Linea()
                Compartir("Tramas de la máquina", almacen.urlTramasDeRemo)
                Linea()
                Compartir("Series de pesas", almacen.urlPesas)
            }

            Bloque(titulo: "Lo que cargás a mano") {
                Compartir("Proteína", almacen.urlConsumo)
                Linea()
                Compartir("Notas", almacen.urlNotas)
                Linea()
                Compartir("Gastos", almacen.urlGastos)
            }

            Bloque(titulo: "Listas que podés editar",
                   pie: "Estos tres se pueden abrir y cambiar a mano desde "
                      + "Archivos → En mi iPad → Yelin App.") {
                Compartir("Frases de la apertura",
                          almacen.documentos.appendingPathComponent("frases.txt"))
                Linea()
                Compartir("Categorías de gastos", almacen.urlCategorias)
                Linea()
                Compartir("Ejercicios de pesas", almacen.urlEjercicios)
                Linea()
                Compartir("Carpetas de notas", almacen.urlCarpetas)
            }

            Bloque(titulo: "Lo que configuraste") {
                Compartir("Objetivos", almacen.urlObjetivos)
                Linea()
                Compartir("Recordatorios", almacen.urlRecordatorios)
            }
        }
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
            HStack(spacing: 11) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Paleta.acento)
                    .frame(width: 18)
                Text(titulo)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Paleta.texto)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Lo crudo que mandan los aparatos. Sirve para descifrar y para calibrar.
struct PantallaTramas: View {
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var remo: LectorDeRemo
    @State private var copiado = ""

    var body: some View {
        Pantalla(titulo: "Tramas crudas",
                 bajada: "Los bytes tal como los manda cada aparato") {
            Bloque(titulo: "Balanza") {
                Fila("Recibidas en esta sesión", "\(balanza.tramasDeLaSesion)")
                Linea()
                Fila("Descartadas", "\(balanza.tramasDescartadas)")
                if !balanza.ultimaTrama.isEmpty {
                    Linea()
                    Cruda(balanza.ultimaTrama)
                }
            }

            Bloque(titulo: "Remo") {
                Fila("Recibidas en esta sesión", "\(remo.cantidadDeTramas)")
                if !remo.nombreDelAparato.isEmpty {
                    Linea()
                    Fila("Aparato", remo.nombreDelAparato)
                }
                if !remo.ultimaTrama.isEmpty {
                    Linea()
                    Cruda(remo.ultimaTrama)
                }
                Linea()
                Accion(texto: copiado == "remo" ? "Copiado" : "Copiar las tramas del remo",
                       simbolo: "doc.on.doc",
                       apagada: remo.cantidadDeTramas == 0) {
                    UIPasteboard.general.string = remo.textoParaCopiar()
                    copiado = "remo"
                }
            }
        }
    }
}

struct Cruda: View {
    let texto: String

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Celda {
            VStack(alignment: .leading, spacing: 4) {
                Text("Última")
                    .font(.system(size: 12))
                    .foregroundColor(Paleta.suave)
                Text(texto)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(Paleta.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
