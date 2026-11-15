import SwiftUI

@main
struct AplicacionYelin: App {
    @StateObject private var sincronizador: Sincronizador
    @StateObject private var balanza: LectorDeBalanza
    @StateObject private var remo: LectorDeRemo

    @State private var abriendo = true

    init() {
        let compartido = Sincronizador()
        _sincronizador = StateObject(wrappedValue: compartido)
        _balanza = StateObject(wrappedValue: LectorDeBalanza(sincronizador: compartido))
        _remo = StateObject(wrappedValue: LectorDeRemo(sincronizador: compartido))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                TabView {
                    PantallaBalanza(balanza: balanza, sincronizador: sincronizador)
                        .tabItem { Label("Balanza", systemImage: "scalemass") }
                    PantallaRemo(remo: remo)
                        .tabItem { Label("Remo", systemImage: "figure.rower") }
                }

                if abriendo {
                    PantallaDeApertura {
                        withAnimation(.easeOut(duration: 0.35)) { abriendo = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}

struct PantallaBalanza: View {
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var sincronizador: Sincronizador

    var body: some View {
        NavigationView {
            List {
                Section {
                    enVivo
                }

                Section {
                    NavigationLink {
                        PantallaPeso(pesadas: balanza.pesadas)
                    } label: {
                        Label("Historial y tendencia", systemImage: "chart.xyaxis.line")
                    }
                }

                Section("Pesadas guardadas") {
                    if balanza.pesadas.isEmpty {
                        Text("Todavía ninguna. Subite a la balanza.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(balanza.pesadas) { pesada in
                            FilaDePesada(pesada: pesada)
                        }
                        .onDelete { indices in
                            indices.map { balanza.pesadas[$0] }.forEach(balanza.borrar)
                        }
                    }
                }

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

                Section("Salud de Apple") {
                    Fila("Permiso", balanza.estadoDeSalud)
                    Button {
                        balanza.pedirPermisoDeSalud()
                    } label: {
                        Label("Dar permiso a Salud", systemImage: "heart.text.square")
                    }
                    if let ultima = balanza.ultimaGuardada {
                        Button {
                            balanza.mandarASalud(ultima)
                        } label: {
                            Label(String(format: "Mandar %.2f kg a Salud", ultima.kg),
                                  systemImage: "arrow.up.heart")
                        }
                    }
                }

                Section("Archivos") {
                    ShareLink(item: balanza.almacen.urlPesadas) {
                        Label("Compartir las pesadas", systemImage: "square.and.arrow.up")
                    }
                    ShareLink(item: balanza.almacen.urlTramas) {
                        Label("Compartir las tramas crudas", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        balanza.buscarDeNuevo()
                    } label: {
                        Label("Buscar la balanza de nuevo", systemImage: "arrow.clockwise")
                    }
                }

                Section("Esta sesión") {
                    Fila("Tramas recibidas", "\(balanza.tramasDeLaSesion)")
                    Fila("Tramas descartadas", "\(balanza.tramasDescartadas)")
                    if !balanza.ultimaTrama.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Última trama").foregroundColor(.secondary)
                            Text(balanza.ultimaTrama)
                                .font(.system(.footnote, design: .monospaced))
                        }
                    }
                    Fila("Versión", Info.version)
                }
            }
            .navigationTitle("Balanza")
            .toolbar { EditButton() }
        }
        .navigationViewStyle(.stack)
    }

    private var enVivo: some View {
        VStack(spacing: 8) {
            if let kg = balanza.pesoKg {
                Text(String(format: "%.2f", kg))
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Text("kg")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(balanza.estado)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

struct FilaDePesada: View {
    let pesada: Pesada

    var body: some View {
        HStack {
            Text(String(format: "%.2f kg", pesada.kg))
                .fontWeight(.medium)
                .monospacedDigit()
            Spacer()
            Text(pesada.instante.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

struct Fila: View {
    let titulo: String
    let valor: String

    init(_ titulo: String, _ valor: String) {
        self.titulo = titulo
        self.valor = valor
    }

    var body: some View {
        HStack {
            Text(titulo).foregroundColor(.secondary)
            Spacer()
            Text(valor).monospacedDigit()
        }
    }
}

enum Info {
    static var version: String {
        let datos = Bundle.main.infoDictionary
        let corta = datos?["CFBundleShortVersionString"] as? String ?? "?"
        let compilacion = datos?["CFBundleVersion"] as? String ?? "?"
        return "\(corta) · compilación \(compilacion)"
    }
}
