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

/// El logo de la app: la opción 82 del diseño, "fondo oscuro, Y5 en cursiva
/// azul".
///
/// Usa Inter ExtraBold Italic, que es la tipografía con la que se diseñó y
/// que viaja incrustada en la app. Las proporciones salen del diseño
/// original: el redondeo es 29/130 del lado, la letra 58/130, y entre la Y y
/// el 5 hay -0,05 em.
struct Logo: View {

    var tamano: CGFloat

    static let tipografia = "Inter-ExtraBoldItalic"

    private var redondeo: CGFloat { tamano * 29 / 130 }
    private var cuerpo: CGFloat { tamano * 58 / 130 }

    var body: some View {
        RoundedRectangle(cornerRadius: redondeo, style: .continuous)
            .fill(Paleta.superficie)
            .overlay(letras)
            .overlay(
                RoundedRectangle(cornerRadius: redondeo, style: .continuous)
                    .stroke(Paleta.borde, lineWidth: 1)
            )
            .frame(width: tamano, height: tamano)
    }

    private var letras: some View {
        HStack(spacing: -cuerpo * 0.05) {
            Text("Y")
            Text("5")
        }
        .font(.custom(Self.tipografia, size: cuerpo))
        .foregroundColor(Paleta.acento)
    }
}

/// Los dos segundos que van desde que tocás la app hasta que la podés usar.
struct PantallaDeApertura: View {
    let terminar: () -> Void

    @Environment(\.horizontalSizeClass) private var anchoDePantalla
    @State private var subio = false
    @State private var mostrarSaludo = false
    @State private var frase = ""

    var body: some View {
        ZStack {
            Paleta.fondo.ignoresSafeArea()

            VStack(spacing: grande ? 34 : 26) {
                Logo(tamano: grande ? 168 : 116)

                if mostrarSaludo {
                    VStack(spacing: grande ? 14 : 12) {
                        Text(saludo)
                            .font(.system(size: grande ? 30 : 22, weight: .semibold))
                            .foregroundColor(Paleta.texto)
                        Text(frase)
                            .font(.system(size: grande ? 18 : 15))
                            .foregroundColor(Paleta.suave)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 44)
            .offset(y: subio ? (grande ? -104 : -78) : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { terminar() }
        .task {
            frase = Frases.proxima()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { subio = true }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeOut(duration: 0.3)) { mostrarSaludo = true }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            terminar()
        }
    }

    /// En tablet todo va más grande; si no, el logo queda perdido en el medio.
    private var grande: Bool { anchoDePantalla == .regular }

    private var saludo: String {
        let hora = Calendar.current.component(.hour, from: Date())
        switch hora {
        case 6..<13:  return "Buenos días, Facundo"
        case 13..<20: return "Buenas tardes, Facundo"
        default:      return "Buenas noches, Facundo"
        }
    }
}
