import SwiftUI

/// La pantalla para mirar mientras rema: un número gigante y nada más.
///
/// Está pensada para el iPad apoyado en el piso adelante de la máquina. Todo
/// lo que no se lee de lejos sobra, así que hay un solo número grande y
/// cuatro chicos abajo. Tocando el número grande se cambia cuál es.
struct PantallaRemoEnVivo: View {
    @ObservedObject var remo: LectorDeRemo
    @Environment(\.dismiss) private var cerrar

    @State private var cual: Metrica = .distancia

    enum Metrica: String, CaseIterable {
        case distancia, ritmo, watts, tiempo

        var rotulo: String {
            switch self {
            case .distancia: return "metros"
            case .ritmo:     return "ritmo por 500 m"
            case .watts:     return "watts"
            case .tiempo:    return "tiempo remando"
            }
        }

        var siguiente: Metrica {
            let todas = Metrica.allCases
            let donde = todas.firstIndex(of: self) ?? 0
            return todas[(donde + 1) % todas.count]
        }
    }

    var body: some View {
        ZStack {
            Paleta.fondo.ignoresSafeArea()

            VStack(spacing: 0) {
                barra
                Spacer(minLength: 0)
                numeroGrande
                Spacer(minLength: 0)
                abajo
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .statusBarHidden()
    }

    // MARK: Arriba

    private var barra: some View {
        HStack(spacing: 12) {
            BotonRedondo(simbolo: "chevron.down") { cerrar() }
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Circle()
                    .fill(remo.sesionAbierta ? Tono.bien : Paleta.suave)
                    .frame(width: 7, height: 7)
                Text(remo.sesionAbierta ? "Sesión en curso" : remo.estado)
                    .font(.system(size: 13))
                    .foregroundColor(Paleta.suave)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            BotonRedondo(simbolo: remo.avisosPorVoz ? "speaker.wave.2.fill" : "speaker.slash",
                         destacado: remo.avisosPorVoz) {
                remo.avisosPorVoz.toggle()
            }
        }
        .padding(.top, 12)
    }

    // MARK: El número

    private var numeroGrande: some View {
        Button {
            cual = cual.siguiente
        } label: {
            VStack(spacing: 4) {
                Text(valorGrande)
                    .font(.system(size: 190, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Paleta.texto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                Text(cual.rotulo)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(Paleta.suave)
                if cual == .distancia, remo.distanciaCalculada > 0 {
                    Text("faltan \(max(0, 10_000 - Int(remo.distanciaCalculada))) para los 10 000")
                        .font(.system(size: 13))
                        .foregroundColor(Paleta.suave.opacity(0.8))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var valorGrande: String {
        switch cual {
        case .distancia: return "\(Int(remo.distanciaCalculada))"
        case .ritmo:     return reloj(remo.datos.ritmoPor500)
        case .watts:     return remo.datos.watts.map { "\($0)" } ?? "—"
        case .tiempo:    return reloj(Int(remo.segundosRemando))
        }
    }

    // MARK: Los chicos

    private var abajo: some View {
        HStack(spacing: 10) {
            chico("Metros", "\(Int(remo.distanciaCalculada))")
            chico("Ritmo", reloj(remo.datos.ritmoPor500))
            chico("Paladas/min", remo.datos.paladasPorMinuto.map {
                String(format: "%.0f", $0)
            } ?? "—")
            chico("Watts", remo.datos.watts.map { "\($0)" } ?? "—")
            chico("Por watts", "\(Int(remo.distanciaPorWatts))")
            chico("Tiempo", reloj(Int(remo.segundosRemando)))
        }
    }

    private func chico(_ rotulo: String, _ valor: String) -> some View {
        VStack(spacing: 3) {
            Text(valor)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Paleta.texto)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(rotulo)
                .font(.system(size: 11))
                .foregroundColor(Paleta.suave)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Paleta.superficie))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Paleta.borde, lineWidth: 1))
    }

    private func reloj(_ segundos: Int?) -> String {
        guard let segundos, segundos > 0 else { return "—" }
        return String(format: "%d:%02d", segundos / 60, segundos % 60)
    }
}
