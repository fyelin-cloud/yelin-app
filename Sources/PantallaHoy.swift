import SwiftUI

/// La pantalla de inicio: el tablero con una ficha por cada parte de la app.
///
/// El peso **no se muestra acá** a propósito: así quedó decidido en el diseño.
/// La ficha dice cuándo fue la última pesada, no cuánto dio.
struct PantallaHoy: View {
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var remo: LectorDeRemo
    @ObservedObject var sincronizador: Sincronizador
    @ObservedObject var diario: Diario
    @ObservedObject var pesas: Pesas
    @ObservedObject var metas: Metas
    @ObservedObject var libreta: Libreta
    @Binding var ir: Seccion

    @Environment(\.horizontalSizeClass) private var anchoDePantalla

    private var columnas: [GridItem] {
        let cuantas = anchoDePantalla == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 13), count: cuantas)
    }

    var body: some View {
        ZStack {
            Paleta.fondo.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    encabezado
                    grilla
                    estaSemana
                    pie
                }
                .padding(.horizontal, Medida.margen)
                .padding(.top, 14)
                .padding(.bottom, 32)
                .frame(maxWidth: Medida.ancho)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Encabezado

    private var encabezado: some View {
        HStack(spacing: 14) {
            Logo(cuerpo: 34)
                .padding(.trailing, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hoy")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Paleta.texto)
                Text(Fechas.larga(Date()))
                    .font(.system(size: 13))
                    .foregroundColor(Paleta.suave)
            }
            Spacer()
        }
    }

    // MARK: Las fichas

    private var grilla: some View {
        LazyVGrid(columns: columnas, spacing: 13) {
            tarjeta(.peso, detalle: detalleDePeso)
            tarjeta(.remo, detalle: detalleDeRemo)
            tarjeta(.pesas, detalle: detalleDePesas)
            tarjeta(.semana, detalle: detalleDeSemana)
            tarjeta(.constancia, detalle: detalleDeConstancia)
            tarjeta(.proteina, detalle: detalleDeProteina)
            tarjeta(.notas, detalle: detalleDeNotas)
            tarjeta(.libreta, detalle: detalleDeLibreta)
            tarjeta(.gastos, detalle: detalleDeGastos)
        }
    }

    /// En tablet todas las secciones están en la columna de la izquierda, así
    /// que la ficha la selecciona. En teléfono solo cinco están en la barra de
    /// abajo; las demás se abren encima del inicio.
    @ViewBuilder
    private func tarjeta(_ s: Seccion, detalle: String) -> some View {
        if anchoDePantalla == .regular || Seccion.enLaBarra.contains(s) {
            Button { ir = s } label: {
                Ficha(titulo: s.titulo, simbolo: s.simbolo, detalle: detalle, activa: true)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                Empuje { destino(s) }
            } label: {
                Ficha(titulo: s.titulo, simbolo: s.simbolo, detalle: detalle, activa: true)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func destino(_ s: Seccion) -> some View {
        switch s {
        case .constancia: PantallaConstancia(balanza: balanza, remo: remo, pesas: pesas)
        case .proteina:   PantallaProteina(diario: diario)
        case .notas:      PantallaNotas(diario: diario)
        case .libreta:    PantallaLibreta(libreta: libreta, diario: diario)
        case .gastos:     PantallaGastos(diario: diario)
        case .semana:     PantallaSemana(balanza: balanza, remo: remo,
                                         diario: diario, pesas: pesas, metas: metas)
        case .pesas:      PantallaPesas(pesas: pesas)
        default:          PantallaAjustes(sincronizador: sincronizador, balanza: balanza,
                                          remo: remo, pesas: pesas, metas: metas)
        }
    }

    // MARK: Lo que dice cada ficha

    /// A propósito no dice cuántos kilos: solo cuándo fue.
    private var detalleDePeso: String {
        guard let ultima = balanza.pesadas.first else { return "Sin registros todavía" }
        return "Última: " + Fechas.conHora(ultima.instante)
    }

    private var detalleDeRemo: String {
        guard let ultima = remo.sesiones.first else { return "Sin sesiones todavía" }
        return String(format: "%.0f m · %@", ultima.metros, Fechas.conHora(ultima.inicio))
    }

    private var detalleDePesas: String {
        if !pesas.seriesDeHoy.isEmpty {
            return "\(pesas.seriesDeHoy.count) series hoy"
        }
        guard let ultimo = pesas.dias().first else { return "Sin series todavía" }
        return "Última vez: " + Fechas.relativa(ultimo.dia)
    }

    private var detalleDeSemana: String {
        let s = semana
        guard s.metros.ahora > 0 || s.volumenDePesas.ahora > 0 else {
            return "Sin entrenamientos"
        }
        return "\(s.diasActivos) de 7 días activos"
    }

    private var detalleDeConstancia: String {
        let c = Constancia.armar(pesadas: balanza.pesadas, sesiones: remo.sesiones,
                                 series: pesas.series)
        if c.rachaActual > 0 {
            return "\(c.rachaActual) " + (c.rachaActual == 1 ? "día seguido" : "días seguidos")
        }
        return "\(c.entrenadosEnTreinta) de los últimos 30"
    }

    private var detalleDeProteina: String {
        let hoy = diario.scoopsDeHoy
        guard hoy > 0 else { return "Nada hoy" }
        return Kilos.texto(hoy) + (hoy == 1 ? " scoop hoy" : " scoops hoy")
    }

    private var detalleDeNotas: String {
        let cuantas = diario.notas.count
        if cuantas == 0 { return "Sin notas todavía" }
        return cuantas == 1 ? "1 nota" : "\(cuantas) notas"
    }

    private var detalleDeLibreta: String {
        let cuantas = libreta.paginas.count
        if cuantas == 0 { return "Sin hojas todavía" }
        guard let ultima = libreta.paginas.first else { return "\(cuantas) hojas" }
        return "\(cuantas) " + (cuantas == 1 ? "hoja" : "hojas")
            + " · " + Fechas.relativa(ultima.modificada)
    }

    private var detalleDeGastos: String {
        let total = diario.totalDelMes()
        guard total > 0 else { return "Sin gastos este mes" }
        return Plata.corto(total) + " este mes"
    }

    // MARK: Un vistazo a la semana

    private var semana: Semana {
        Semana.armar(pesadas: balanza.pesadas, sesiones: remo.sesiones,
                     consumo: diario.consumo, gastos: diario.gastos,
                     series: pesas.series)
    }

    private var estaSemana: some View {
        let s = semana
        let o = metas.objetivos
        return Bloque(titulo: "Esta semana") {
            Celda {
                HStack(spacing: 0) {
                    Resumido(valor: s.metros.ahora > 0 ? Kilos.grande(s.metros.ahora) : "—",
                             rotulo: o.metrosPorSemana.map {
                                 "de " + Kilos.grande($0) + " m"
                             } ?? "metros")
                    Separador()
                    Resumido(valor: s.volumenDePesas.ahora > 0
                                  ? Kilos.grande(s.volumenDePesas.ahora) : "—",
                             rotulo: "kg de pesas")
                    Separador()
                    Resumido(valor: o.diasPorSemana.map { "\(s.diasActivos)/\($0)" }
                                  ?? "\(s.diasActivos)/7",
                             rotulo: "días activos")
                }
            }
        }
    }

    // MARK: Pie

    private var pie: some View {
        NavigationLink {
            Empuje {
                PantallaAjustes(sincronizador: sincronizador, balanza: balanza,
                                remo: remo, pesas: pesas, metas: metas)
            }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    LineaDeEstado(simbolo: "arrow.up.circle", texto: sincronizador.estado)
                    LineaDeEstado(simbolo: "signature",
                                  texto: "Firma: " + Firma.resumen.lowercased())
                    LineaDeEstado(simbolo: "number", texto: Info.version)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Paleta.suave)
                    .padding(.top, 2)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}

/// Un número chico con su palabra, de los tres que van en "Esta semana".
private struct Resumido: View {
    let valor: String
    let rotulo: String

    var body: some View {
        VStack(spacing: 2) {
            Text(valor)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Paleta.texto)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(rotulo)
                .font(.system(size: 11))
                .foregroundColor(Paleta.suave)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Separador: View {
    var body: some View {
        Rectangle()
            .fill(Paleta.borde)
            .frame(width: 1, height: 30)
    }
}

/// Una ficha de la grilla de inicio.
struct Ficha: View {
    let titulo: String
    let simbolo: String
    let detalle: String
    let activa: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: simbolo)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(activa ? Paleta.acento : Paleta.suave)
            Spacer(minLength: 10)
            Text(titulo)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(activa ? Paleta.texto : Paleta.suave)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detalle)
                .font(.system(size: 11.5))
                .foregroundColor(Paleta.suave)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 122)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Medida.radio, style: .continuous)
            .fill(Paleta.superficie))
        .overlay(RoundedRectangle(cornerRadius: Medida.radio, style: .continuous)
            .stroke(Paleta.borde, lineWidth: 1))
        .opacity(activa ? 1 : 0.5)
    }
}

struct LineaDeEstado: View {
    let simbolo: String
    let texto: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: simbolo)
                .font(.system(size: 11))
                .foregroundColor(Paleta.suave)
                .frame(width: 14)
            Text(texto)
                .font(.system(size: 12))
                .foregroundColor(Paleta.suave)
                .lineLimit(1)
        }
    }
}

extension String {
    /// "domingo 15 de noviembre" -> "Domingo 15 de noviembre"
    var capitalizedPrimera: String {
        guard let primera = first else { return self }
        return primera.uppercased() + dropFirst()
    }
}
