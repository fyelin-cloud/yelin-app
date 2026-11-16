import SwiftUI

/// El calendario de actividad: un cuadradito por día de los últimos tres meses.
struct PantallaConstancia: View {
    @ObservedObject var balanza: LectorDeBalanza
    @ObservedObject var remo: LectorDeRemo
    @ObservedObject var pesas: Pesas

    private var datos: Constancia {
        Constancia.armar(pesadas: balanza.pesadas,
                         sesiones: remo.sesiones,
                         series: pesas.series)
    }

    var body: some View {
        let c = datos
        return Pantalla(titulo: "Constancia",
                        bajada: "Los últimos tres meses, un cuadradito por día") {
            Bloque {
                Grilla(semanas: c.semanas)
                Linea()
                Celda {
                    HStack(spacing: 14) {
                        Referencia(nivel: 1, texto: "Te pesaste")
                        Referencia(nivel: 2, texto: "Entrenaste")
                        Referencia(nivel: 3, texto: "Remo y pesas")
                    }
                }
            }

            Bloque(titulo: "Rachas") {
                Fila("Días seguidos entrenando", "\(c.rachaActual)",
                     resaltado: c.rachaActual > 0)
                Linea()
                Fila("La racha más larga", "\(c.rachaMasLarga)")
                Linea()
                Fila("Entrenados en los últimos 30", "\(c.entrenadosEnTreinta) de 30")
                Linea()
                Fila("Días entrenados en total", "\(c.totalEntrenados)")
                Linea()
                Fila("Días que te pesaste", "\(c.diasConPesada)")
            }

            Bloque(pie: "La racha cuenta días con remo o con pesas. Pesarse no la "
                      + "mantiene: es un registro, no un entrenamiento.") {
                Celda {
                    Text(frase(c))
                        .font(.system(size: 14))
                        .foregroundColor(Paleta.texto)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func frase(_ c: Constancia) -> String {
        if c.totalEntrenados == 0 {
            return "Todavía no hay ningún día con entrenamiento registrado."
        }
        if c.rachaActual == 0 {
            return "Hoy no entrenaste. La racha más larga que llevaste fue de "
                + "\(c.rachaMasLarga) " + (c.rachaMasLarga == 1 ? "día" : "días") + "."
        }
        if c.rachaActual >= c.rachaMasLarga {
            return "Vas \(c.rachaActual) " + (c.rachaActual == 1 ? "día" : "días")
                + " seguidos: es tu racha más larga hasta ahora."
        }
        return "Vas \(c.rachaActual) " + (c.rachaActual == 1 ? "día" : "días")
            + " seguidos. Tu récord es \(c.rachaMasLarga)."
    }
}

/// La grilla de cuadraditos, una columna por semana.
private struct Grilla: View {
    let semanas: [[Constancia.Dia]]

    private let lado: CGFloat = 13
    private let hueco: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            meses
            HStack(alignment: .top, spacing: hueco) {
                iniciales
                ForEach(enumerar(semanas)) { columna in
                    VStack(spacing: hueco) {
                        ForEach(columna.valor) { dia in
                            Cuadradito(dia: dia, lado: lado)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    /// El nombre del mes arriba de la primera semana que cae en ese mes.
    private var meses: some View {
        HStack(spacing: hueco) {
            Spacer().frame(width: 16)
            ForEach(enumerar(semanas)) { columna in
                Text(etiqueta(columna))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Paleta.suave)
                    .frame(width: lado, alignment: .leading)
                    .fixedSize()
            }
        }
        .frame(height: 11, alignment: .bottomLeading)
        .clipped()
    }

    private func etiqueta(_ columna: Enumerada<[Constancia.Dia]>) -> String {
        guard let primero = columna.valor.first else { return "" }
        let calendario = Calendar.current
        let mes = calendario.component(.month, from: primero.dia)
        if columna.puesto == 0 { return Fechas.mes(primero.dia) }
        let anterior = semanas[columna.puesto - 1]
        guard let referencia = anterior.first else { return "" }
        let mesAnterior = calendario.component(.month, from: referencia.dia)
        return mes != mesAnterior ? Fechas.mes(primero.dia) : ""
    }

    private var iniciales: some View {
        VStack(spacing: hueco) {
            ForEach(0..<7, id: \.self) { fila in
                Text(inicial(fila))
                    .font(.system(size: 8))
                    .foregroundColor(Paleta.suave)
                    .frame(width: 16, height: lado, alignment: .leading)
            }
        }
    }

    private func inicial(_ fila: Int) -> String {
        let calendario = Calendar.current
        let numero = (calendario.firstWeekday - 1 + fila) % 7 + 1
        return fila % 2 == 0 ? Fechas.inicialDelDia(numero) : ""
    }
}

private struct Cuadradito: View {
    let dia: Constancia.Dia
    let lado: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .frame(width: lado, height: lado)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Paleta.texto.opacity(esHoy ? 0.85 : 0), lineWidth: 1)
            )
            .opacity(dia.esFuturo ? 0.25 : 1)
    }

    private var esHoy: Bool { Calendar.current.isDateInToday(dia.dia) }

    private var color: Color {
        switch dia.nivel {
        case 3: return Paleta.acento
        case 2: return Paleta.acento.opacity(0.62)
        case 1: return Paleta.acento.opacity(0.22)
        default: return Paleta.borde.opacity(0.75)
        }
    }
}

private struct Referencia: View {
    let nivel: Int
    let texto: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(texto)
                .font(.system(size: 11))
                .foregroundColor(Paleta.suave)
        }
    }

    private var color: Color {
        switch nivel {
        case 3: return Paleta.acento
        case 2: return Paleta.acento.opacity(0.62)
        default: return Paleta.acento.opacity(0.22)
        }
    }
}
