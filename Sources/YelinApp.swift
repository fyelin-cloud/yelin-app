import SwiftUI

@main
struct AplicacionYelin: App {
    @StateObject private var sincronizador: Sincronizador
    @StateObject private var balanza: LectorDeBalanza
    @StateObject private var remo: LectorDeRemo
    @StateObject private var diario: Diario
    @StateObject private var pesas: Pesas
    @StateObject private var metas: Metas
    @StateObject private var libreta: Libreta

    @State private var abriendo = true

    init() {
        Firma.registrar()
        let compartido = Sincronizador()
        _sincronizador = StateObject(wrappedValue: compartido)
        _balanza = StateObject(wrappedValue: LectorDeBalanza(sincronizador: compartido))
        _remo = StateObject(wrappedValue: LectorDeRemo(sincronizador: compartido))
        let cuaderno = Diario(sincronizador: compartido)
        _diario = StateObject(wrappedValue: cuaderno)
        _pesas = StateObject(wrappedValue: Pesas(sincronizador: compartido))
        _metas = StateObject(wrappedValue: Metas(sincronizador: compartido))
        _libreta = StateObject(wrappedValue: Libreta(sincronizador: compartido))
        Avisos.compartido.arrancar(sincronizador: compartido, diario: cuaderno)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Raiz(sincronizador: sincronizador, balanza: balanza,
                     remo: remo, diario: diario, pesas: pesas, metas: metas,
                     libreta: libreta)

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

// MARK: - Las partes de la app

/// Cada pantalla que se puede abrir desde el menú.
enum Seccion: String, CaseIterable, Identifiable {
    case hoy, semana, constancia, peso, remo, pesas, proteina, notas, libreta,
         gastos, ajustes

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .hoy: return "Hoy"
        case .semana: return "La semana"
        case .constancia: return "Constancia"
        case .peso: return "Peso"
        case .remo: return "Remo"
        case .pesas: return "Pesas"
        case .proteina: return "Proteína"
        case .notas: return "Notas"
        case .libreta: return "Libreta"
        case .gastos: return "Gastos"
        case .ajustes: return "Ajustes"
        }
    }

    var simbolo: String {
        switch self {
        case .hoy: return "square.grid.2x2"
        case .semana: return "calendar.badge.clock"
        case .constancia: return "square.grid.3x3"
        case .peso: return "scalemass"
        case .remo: return "figure.rower"
        case .pesas: return "dumbbell"
        case .proteina: return "cup.and.saucer"
        case .notas: return "note.text"
        case .libreta: return "pencil.and.outline"
        case .gastos: return "dollarsign.circle"
        case .ajustes: return "gearshape"
        }
    }
}

/// Decide cómo se navega según el tamaño de la pantalla.
///
/// **En tablet** va una columna fija a la izquierda con todas las secciones a
/// la vista, que es lo que corresponde en una pantalla grande: la barrita de
/// abajo queda perdida y encima lejos de la mano cuando el iPad está apoyado.
///
/// **En teléfono** se queda la barra de abajo con las cinco que más se usan;
/// el resto se abre desde el inicio.
struct Raiz: View {
    @ObservedObject var sincronizador: Sincronizador
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var remo: LectorDeRemo
    @ObservedObject var diario: Diario
    @ObservedObject var pesas: Pesas
    @ObservedObject var metas: Metas
    @ObservedObject var libreta: Libreta

    @Environment(\.horizontalSizeClass) private var anchoDePantalla
    @State private var seccion: Seccion = .hoy

    var body: some View {
        if anchoDePantalla == .regular {
            conColumna
        } else {
            conBarra
        }
    }

    // MARK: Tablet

    /// Dos columnas puestas a mano, sin `NavigationSplitView`.
    ///
    /// El split view del sistema trae su botón de plegar, su material
    /// translúcido y su propio ancho; nada de eso se puede cambiar. Dos cosas
    /// al lado de la otra se arman en una línea y quedan como queremos.
    private var conColumna: some View {
        HStack(spacing: 0) {
            Lateral(seleccion: $seccion)
                .frame(width: 252)
            Rectangle()
                .fill(Paleta.borde)
                .frame(width: 1)
                .ignoresSafeArea(edges: .vertical)
            NavigationStack { vista(seccion) }
                .id(seccion)
        }
        .background(Paleta.fondo.ignoresSafeArea())
        .tint(Paleta.acento)
    }

    // MARK: Teléfono

    /// Una sola pila de navegación con nuestra barra abajo, en lugar del
    /// `TabView` del sistema.
    ///
    /// El `TabView` dibuja la barra translúcida de iOS con sus íconos
    /// chiquitos y sus rótulos de diez puntos, y no se puede repintar.
    private var conBarra: some View {
        NavigationStack { vista(seccion) }
            .id(seccion)
            .background(Paleta.fondo.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BarraDeAbajo(seleccion: $seccion)
            }
            .tint(Paleta.acento)
    }

    // MARK: Qué pantalla es cada sección

    @ViewBuilder
    private func vista(_ s: Seccion) -> some View {
        switch s {
        case .hoy:
            PantallaHoy(balanza: balanza, remo: remo, sincronizador: sincronizador,
                        diario: diario, pesas: pesas, metas: metas, libreta: libreta,
                        ir: $seccion)
        case .semana:
            PantallaSemana(balanza: balanza, remo: remo, diario: diario,
                           pesas: pesas, metas: metas)
        case .constancia:
            PantallaConstancia(balanza: balanza, remo: remo, pesas: pesas)
        case .peso:
            PantallaBalanza(balanza: balanza, sincronizador: sincronizador, metas: metas)
        case .remo:
            PantallaRemo(remo: remo)
        case .pesas:
            PantallaPesas(pesas: pesas)
        case .proteina:
            PantallaProteina(diario: diario)
        case .notas:
            PantallaNotas(diario: diario)
        case .libreta:
            PantallaLibreta(libreta: libreta, diario: diario)
        case .gastos:
            PantallaGastos(diario: diario)
        case .ajustes:
            PantallaAjustes(sincronizador: sincronizador, balanza: balanza,
                            remo: remo, pesas: pesas, metas: metas)
        }
    }
}

extension Seccion {
    /// Las que entran en la barra de abajo del teléfono. Cinco es el máximo
    /// antes de que iOS las amontone detrás de un "más".
    static let enLaBarra: [Seccion] = [.hoy, .peso, .remo, .pesas, .semana]

    /// Cómo se agrupan en la columna del iPad.
    static let grupos: [(String?, [Seccion])] = [
        (nil, [.hoy, .semana, .constancia]),
        ("El cuerpo", [.peso, .remo, .pesas]),
        ("Día a día", [.proteina, .notas, .libreta, .gastos]),
        (nil, [.ajustes])
    ]
}

// MARK: - La barra de abajo del teléfono

/// Las cinco secciones principales. Dibujada a mano: fondo sólido de la
/// marca, borde fino arriba y una pastilla azul atrás de la elegida.
struct BarraDeAbajo: View {
    @Binding var seleccion: Seccion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Seccion.enLaBarra) { s in
                Button {
                    seleccion = s
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: s.simbolo)
                            .font(.system(size: 17,
                                          weight: seleccion == s ? .semibold : .regular))
                        Text(s.titulo)
                            .font(.system(size: 10.5,
                                          weight: seleccion == s ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(seleccion == s ? Paleta.acento : Paleta.suave)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(seleccion == s ? Paleta.acento.opacity(0.14) : Color.clear)
                            .padding(.horizontal, 6)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Paleta.superficie)
        .overlay(alignment: .top) {
            Rectangle().fill(Paleta.borde).frame(height: 1)
        }
    }
}

// MARK: - La columna del iPad

struct Lateral: View {
    @Binding var seleccion: Seccion

    var body: some View {
        ZStack {
            Paleta.fondo.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Logo(cuerpo: 40)
                        .padding(.leading, 12)
                        .padding(.top, 8)

                    ForEach(enumerar(Seccion.grupos)) { grupo in
                        VStack(alignment: .leading, spacing: 3) {
                            if let titulo = grupo.valor.0 {
                                Rotulo(titulo)
                                    .padding(.leading, 8)
                                    .padding(.bottom, 2)
                            }
                            ForEach(grupo.valor.1) { s in
                                Button { seleccion = s } label: {
                                    FilaLateral(seccion: s, elegida: seleccion == s)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct FilaLateral: View {
    let seccion: Seccion
    let elegida: Bool

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: seccion.simbolo)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(elegida ? Paleta.acento : Paleta.suave)
                .frame(width: 20)
            Text(seccion.titulo)
                .font(.system(size: 15, weight: elegida ? .semibold : .regular))
                .foregroundColor(elegida ? Paleta.texto : Paleta.texto.opacity(0.82))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(elegida ? Paleta.acento.opacity(0.16) : Color.clear))
        .contentShape(Rectangle())
    }
}

// MARK: - Balanza

struct PantallaBalanza: View {
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var sincronizador: Sincronizador
    @ObservedObject var metas: Metas

    @State private var cargandoAMano = false
    @State private var corrigiendo: Pesada?

    var body: some View {
        Pantalla(titulo: "Peso",
                 simbolo: "arrow.clockwise",
                 accion: { balanza.buscarDeNuevo() }) {
            Hero(numero: balanza.pesoKg.map { String(format: "%.2f", $0) } ?? "—",
                 unidad: "kg",
                 estado: balanza.estado,
                 señal: señal,
                 alPie: balanza.pesadas.isEmpty ? nil
                      : "\(balanza.pesadas.count) pesadas guardadas")

            if metas.objetivos.peso != nil { objetivo }

            Bloque {
                Navega(texto: "Historial y tendencia", simbolo: "chart.xyaxis.line") {
                    PantallaPeso(pesadas: balanza.pesadas, metas: metas)
                }
                Linea()
                Accion(texto: "Cargar una pesada a mano", simbolo: "plus.circle") {
                    cargandoAMano = true
                }
            }

            Bloque(titulo: "Pesadas guardadas",
                   pie: balanza.pesadas.isEmpty ? nil
                      : "Tocá una pesada para corregirla. Mantené apretada para "
                      + "borrarla.") {
                if balanza.pesadas.isEmpty {
                    Vacio("Todavía ninguna. Subite a la balanza.")
                } else {
                    ForEach(enumerar(Array(balanza.pesadas.prefix(60)))) { fila in
                        if fila.puesto > 0 { Linea() }
                        Button { corrigiendo = fila.valor } label: {
                            FilaDePesada(pesada: fila.valor)
                        }
                        .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    balanza.borrar(fila.valor)
                                } label: {
                                    Label("Borrar esta pesada", systemImage: "trash")
                                }
                            }
                    }
                    if balanza.pesadas.count > 60 {
                        Linea()
                        Celda {
                            Text("Y \(balanza.pesadas.count - 60) más. Están todas en el historial y en el archivo.")
                                .font(.system(size: 12))
                                .foregroundColor(Paleta.suave)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $cargandoAMano) {
            EditorDePesada { kg, cuando in
                balanza.agregarAMano(kg: kg, instante: cuando)
            }
        }
        .sheet(item: $corrigiendo) { pesada in
            EditorDePesada(pesada: pesada) { kg, cuando in
                balanza.reemplazar(pesada, kg: kg, instante: cuando)
            }
        }
    }

    /// Cuánto falta para el peso objetivo y, si la tendencia apunta para
    /// ese lado, en qué fecha se llegaría.
    private var objetivo: some View {
        let o = metas.objetivos
        let ultimo = balanza.pesadas.first?.kg
        let puntos = Analisis.porDia(balanza.pesadas)
        let porSemana = Analisis.tendenciaPorSemana(puntos)
        let falta = o.faltaParaElPeso(desde: ultimo)
        let cuando = o.fechaEstimada(desde: ultimo, porSemana: porSemana)

        return Bloque(titulo: "Objetivo",
                      pie: cuando == nil && falta != nil
                         ? "La fecha aparece cuando la tendencia apunta al objetivo."
                         : "La fecha es la cuenta de dividir lo que falta por lo que "
                         + "viene cambiando por semana. No es una promesa.") {
            Fila("Peso al que apuntás", String(format: "%.1f kg", o.peso ?? 0))
            Linea()
            if let falta {
                Fila(falta < 0 ? "Falta bajar" : "Falta subir",
                     String(format: "%.2f kg", abs(falta)),
                     resaltado: abs(falta) < 0.3)
            } else {
                Fila("Falta", "pesate para saber")
            }
            if let cuando {
                Linea()
                Fila("Llegarías el", Fechas.conAnio(cuando))
            }
        }
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
            Text(String(format: "%.2f", pesada.kg))
                .font(.system(size: 16, weight: .medium))
                .monospacedDigit()
                .foregroundColor(Paleta.texto)
            Text("kg")
                .font(.system(size: 12))
                .foregroundColor(Paleta.suave)
            Spacer()
            Text(pesada.instante.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12))
                .foregroundColor(Paleta.suave)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
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
