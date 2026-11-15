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

/// El logo de la app: la Y y el 5 dibujados en una grilla de píxeles.
///
/// Es el logo que se eligió en el diseño. Va dibujado con rectángulos en vez
/// de ser una imagen, así se adapta a cualquier tamaño sin perder el filo y
/// se le pueden cambiar los colores según el fondo.
struct Logo: View {

    var colorY: Color = Paleta.acento
    var colorCinco: Color = Paleta.texto

    /// Celdas de la grilla: x, y, ancho, alto.
    private static let celdasY = [(1, 1, 2, 2), (5, 1, 2, 2),
                                  (2, 3, 2, 2), (4, 3, 2, 2),
                                  (3, 5, 2, 2), (3, 7, 2, 2), (3, 9, 2, 2)]
    private static let celdasCinco = [(8, 1, 5, 2), (8, 3, 2, 2),
                                      (8, 5, 5, 2), (11, 7, 2, 2), (8, 9, 5, 2)]

    /// El dibujo ocupa 12 celdas de ancho por 10 de alto.
    static let proporcion: CGFloat = 12.0 / 10.0

    var body: some View {
        Canvas { contexto, tamano in
            let celda = tamano.width / 12
            pintar(Self.celdasY, color: colorY, celda: celda, en: contexto)
            pintar(Self.celdasCinco, color: colorCinco, celda: celda, en: contexto)
        }
        .aspectRatio(Self.proporcion, contentMode: .fit)
    }

    private func pintar(_ celdas: [(Int, Int, Int, Int)], color: Color,
                        celda: CGFloat, en contexto: GraphicsContext) {
        for (x, y, ancho, alto) in celdas {
            let marco = CGRect(x: CGFloat(x - 1) * celda,
                               y: CGFloat(y - 1) * celda,
                               width: CGFloat(ancho) * celda,
                               height: CGFloat(alto) * celda)
            contexto.fill(Path(marco), with: .color(color))
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
            Paleta.fondo.ignoresSafeArea()

            VStack(spacing: 26) {
                Logo()
                    .frame(width: 132)

                if mostrarSaludo {
                    VStack(spacing: 12) {
                        Text(saludo)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Paleta.texto)
                        Text(frase)
                            .font(.system(size: 15))
                            .foregroundColor(Paleta.suave)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 44)
            .offset(y: subio ? -78 : 0)
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

    private var saludo: String {
        let hora = Calendar.current.component(.hour, from: Date())
        switch hora {
        case 6..<13:  return "Buenos días, Facundo"
        case 13..<20: return "Buenas tardes, Facundo"
        default:      return "Buenas noches, Facundo"
        }
    }
}
