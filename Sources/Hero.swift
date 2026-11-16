import SwiftUI

/// El número grande de arriba de todo, en una ficha con los colores de la marca.
///
/// Lo comparten la balanza y el remo: es lo que más se mira, así que conviene
/// que se vea igual en las dos y que no quede con el gris de iOS.
struct Hero: View {
    let numero: String
    let unidad: String
    let estado: String
    let señal: Señal
    var alPie: String?

    enum Señal {
        case conectado, esperando, apagado

        var color: Color {
            switch self {
            case .conectado: return Color(red: 0.26, green: 0.78, blue: 0.47)
            case .esperando: return Paleta.acento
            case .apagado:   return Paleta.suave
            }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(numero)
                .font(.system(size: 74, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Paleta.texto)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(unidad)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Paleta.suave)

            HStack(spacing: 7) {
                Circle()
                    .fill(señal.color)
                    .frame(width: 7, height: 7)
                Text(estado)
                    .font(.system(size: 13))
                    .foregroundColor(Paleta.suave)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 2)

            if let alPie {
                Text(alPie)
                    .font(.system(size: 12))
                    .foregroundColor(Paleta.suave)
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Paleta.superficie))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Paleta.borde, lineWidth: 1))
    }
}
