import SwiftUI

/// Las frases que aparecen al abrir la app.
///
/// Viven en un archivo de texto dentro de la app, no en el código, así se
/// pueden cambiar desde Archivos → En mi iPad → Yelin App → frases.txt sin
/// recompilar nada. Una frase por línea.
enum Frases {

    static let porDefecto = [
        "Lo que se sostiene, se nota.",
        "Un día más en la serie.",
        "La constancia no hace ruido.",
        "Empezar ya es la mitad.",
        "Seguís acá, y eso cuenta.",
        "De a poco también es un ritmo.",
        "Hoy alcanza con aparecer.",
        "Lo de ayer ya está hecho.",
        "Un paso, y después se ve.",
        "La suma importa más que el día.",
        "Despacio también llega.",
        "Cada vez cuesta un poco menos.",
        "No hace falta que sea perfecto.",
        "Volver cuenta igual que seguir.",
        "Lo simple sostenido gana.",
        "Hoy es un día más, y está bien.",
        "El ritmo propio también es ritmo.",
        "Lo que repetís, te arma.",
        "Arrancar es lo difícil, y ya está.",
        "Sin apuro, pero seguido.",
        "Mañana se agradece lo de hoy.",
        "Nada que demostrar."
    ]

    private static var archivo: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("frases.txt")
    }

    static func todas() -> [String] {
        if let texto = try? String(contentsOf: archivo, encoding: .utf8) {
            let lineas = texto.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            if !lineas.isEmpty { return lineas }
        }
        sembrar()
        return porDefecto
    }

    private static func sembrar() {
        let cabecera = "# Las frases de la pantalla de apertura, una por línea.\n"
            + "# Podés agregar, borrar o cambiar las que quieras.\n"
            + "# Las líneas que empiezan con # no se usan.\n\n"
        try? (cabecera + porDefecto.joined(separator: "\n") + "\n")
            .write(to: archivo, atomically: true, encoding: .utf8)
    }

    /// Una frase al azar, nunca la misma dos veces seguidas.
    static func proxima() -> String {
        let lista = todas()
        guard lista.count > 1 else { return lista.first ?? "" }
        let anterior = UserDefaults.standard.string(forKey: "ultimaFrase")
        let candidatas = lista.filter { $0 != anterior }
        let elegida = candidatas.randomElement() ?? lista[0]
        UserDefaults.standard.set(elegida, forKey: "ultimaFrase")
        return elegida
    }
}

/// El logo de la app.
struct Logo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.15, green: 0.39, blue: 0.92),
                                              Color(red: 0.08, green: 0.72, blue: 0.65)],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
            Text("Y")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

/// Los dos segundos que van desde que tocás la app hasta que la podés usar.
struct PantallaDeApertura: View {
    let terminar: () -> Void

    @State private var subio = false
    @State private var mostrarSaludo = false
    @State private var frase = ""

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 22) {
                Logo()
                    .frame(width: 92, height: 92)

                if mostrarSaludo {
                    VStack(spacing: 10) {
                        Text(saludo)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(frase)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 40)
            .offset(y: subio ? -70 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { terminar() }
        .task {
            frase = Frases.proxima()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { subio = true }
            try? await Task.sleep(nanoseconds: 320_000_000)
            withAnimation(.easeOut(duration: 0.28)) { mostrarSaludo = true }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            terminar()
        }
    }

    private var saludo: String {
        let hora = Calendar.current.component(.hour, from: Date())
        switch hora {
        case 6..<13:  return "Buenos días, Facundo"
        case 13..<20: return "Buenas tardes, Facundo"
        default:      return "Buenas noches, Facundo"
        }
    }
}
