import SwiftUI

@main
struct AplicacionYelin: App {
    @StateObject private var sincronizador: Sincronizador
    @StateObject private var balanza: LectorDeBalanza
    @StateObject private var remo: LectorDeRemo
    @StateObject private var diario: Diario

    @State private var abriendo = true
    @State private var pestana = 0

    init() {
        Firma.registrar()
        let compartido = Sincronizador()
        _sincronizador = StateObject(wrappedValue: compartido)
        _balanza = StateObject(wrappedValue: LectorDeBalanza(sincronizador: compartido))
        _remo = StateObject(wrappedValue: LectorDeRemo(sincronizador: compartido))
        _diario = StateObject(wrappedValue: Diario(sincronizador: compartido))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                TabView(selection: $pestana) {
                    PantallaHoy(balanza: balanza, remo: remo,
                                sincronizador: sincronizador, diario: diario,
                                pestana: $pestana)
                        .tabItem { Label("Hoy", systemImage: "square.grid.2x2") }
                        .tag(0)
                    PantallaBalanza(balanza: balanza, sincronizador: sincronizador)
                        .tabItem { Label("Balanza", systemImage: "scalemass") }
                        .tag(1)
                    PantallaRemo(remo: remo)
                        .tabItem { Label("Remo", systemImage: "figure.rower") }
                        .tag(2)
                }
                .tint(Paleta.acento)

                if abriendo {
                    PantallaDeApertura {
                        withAnimation(.easeOut(duration: 0.35)) { abriendo = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct PantallaBalanza: View {
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var sincronizador: Sincronizador

    var body: some View {
        NavigationView {
            List {
                Section { enVivo }

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
            }
            .scrollContentBackground(.hidden)
            .background(Paleta.fondo)
            .navigationTitle("Balanza")
            .toolbar { EditButton() }
        }
        .navigationViewStyle(.stack)
    }

    private var enVivo: some View {
        Hero(numero: balanza.pesoKg.map { String(format: "%.2f", $0) } ?? "—",
             unidad: "kg",
             estado: balanza.estado,
             señal: señal,
             alPie: balanza.pesadas.isEmpty ? nil
                  : "\(balanza.pesadas.count) pesadas guardadas")
    }

    private var señal: Hero.Señal {
        if balanza.pesoKg != nil { return .conectado }
        if balanza.estado.contains("apagado") || balanza.estado.contains("permiso") {
            return .apagado
        }
        return .esperando
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
