import SwiftUI

@main
struct AplicacionYelin: App {
    @StateObject private var balanza = LectorDeBalanza()

    var body: some Scene {
        WindowGroup {
            PantallaBalanza(balanza: balanza)
        }
    }
}

struct PantallaBalanza: View {
    @ObservedObject var balanza: LectorDeBalanza

    var body: some View {
        NavigationView {
            List {
                Section {
                    enVivo
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
