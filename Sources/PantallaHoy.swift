import SwiftUI

/// La pantalla de inicio: una grilla de fichas, una por cada parte de la app.
///
/// El peso **no se muestra acá** a propósito: así quedó decidido en el diseño.
/// La ficha dice cuándo fue la última pesada, no cuánto dio.
struct PantallaHoy: View {
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var remo: LectorDeRemo
    @ObservedObject var sincronizador: Sincronizador
    @Binding var pestana: Int

    private let columnas = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        ZStack {
            Paleta.fondo.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    encabezado
                    grilla
                    pie
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Encabezado

    private var encabezado: some View {
        HStack(spacing: 14) {
            Logo()
                .frame(width: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hoy")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Paleta.texto)
                Text(fechaDeHoy)
                    .font(.system(size: 13))
                    .foregroundColor(Paleta.suave)
            }
            Spacer()
        }
    }

    private var fechaDeHoy: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.dateFormat = "EEEE d 'de' MMMM"
        return f.string(from: Date()).capitalizedPrimera
    }

    // MARK: Grilla

    private var grilla: some View {
        LazyVGrid(columns: columnas, spacing: 14) {
            Ficha(titulo: "Peso",
                  simbolo: "scalemass",
                  detalle: detalleDePeso,
                  activa: true) { pestana = 1 }

            Ficha(titulo: "Remo",
                  simbolo: "figure.rower",
                  detalle: detalleDeRemo,
                  activa: true) { pestana = 2 }

            Ficha(titulo: "Pesas", simbolo: "dumbbell", detalle: "Pronto", activa: false) {}
            Ficha(titulo: "Proteína", simbolo: "cup.and.saucer", detalle: "Pronto", activa: false) {}
            Ficha(titulo: "Notas", simbolo: "note.text", detalle: "Pronto", activa: false) {}
            Ficha(titulo: "Gastos", simbolo: "dollarsign.circle", detalle: "Pronto", activa: false) {}
        }
    }

    /// A propósito no dice cuántos kilos: solo cuándo fue.
    private var detalleDePeso: String {
        guard let ultima = balanza.pesadas.first else { return "Sin registros todavía" }
        return "Última: " + cuandoFue(ultima.instante)
    }

    private var detalleDeRemo: String {
        guard let ultima = remo.sesiones.first else { return "Sin sesiones todavía" }
        return String(format: "%.0f m · %@", ultima.metros, cuandoFue(ultima.inicio))
    }

    private func cuandoFue(_ fecha: Date) -> String {
        let calendario = Calendar.current
        if calendario.isDateInToday(fecha) {
            return "hoy " + fecha.formatted(date: .omitted, time: .shortened)
        }
        if calendario.isDateInYesterday(fecha) { return "ayer" }
        let dias = calendario.dateComponents([.day],
                                             from: calendario.startOfDay(for: fecha),
                                             to: calendario.startOfDay(for: Date())).day ?? 0
        if dias < 7 { return "hace \(dias) días" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.dateFormat = "d/M"
        return f.string(from: fecha)
    }

    // MARK: Pie

    private var pie: some View {
        VStack(alignment: .leading, spacing: 8) {
            LineaDeEstado(simbolo: "arrow.up.circle", texto: sincronizador.estado)
            LineaDeEstado(simbolo: "signature", texto: "Firma: " + Firma.resumen.lowercased())
            LineaDeEstado(simbolo: "number", texto: Info.version)
        }
        .padding(.top, 4)
    }
}

/// Una ficha de la grilla de inicio.
struct Ficha: View {
    let titulo: String
    let simbolo: String
    let detalle: String
    let activa: Bool
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: simbolo)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundColor(activa ? Paleta.acento : Paleta.suave)
                Spacer(minLength: 12)
                Text(titulo)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(activa ? Paleta.texto : Paleta.suave)
                Text(detalle)
                    .font(.system(size: 12))
                    .foregroundColor(Paleta.suave)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 124)
            .padding(15)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Paleta.superficie))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Paleta.borde, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!activa)
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
