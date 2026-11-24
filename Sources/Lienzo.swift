import SwiftUI
import PencilKit

/// La hoja donde se escribe con el Pencil.
///
/// PencilKit no tiene versión de SwiftUI, así que esto envuelve la vista de
/// UIKit. Tres decisiones que conviene no deshacer:
///
/// - **El papel es claro aunque la app sea oscura.** Escribir en negro sobre
///   negro no se lee, y la imagen que se exporta tiene que servir para mirar
///   e imprimir. Por eso la hoja va forzada a modo claro: si no, iOS le da
///   vuelta los colores a la tinta.
/// - **No hay botón de guardar.** Cada vez que deja de escribir por un
///   segundo y medio, se guarda solo.
/// - **La hoja crece para abajo**, así se puede seguir escribiendo sin
///   cambiar de página.
struct Lienzo: UIViewRepresentable {
    @Binding var dibujo: PKDrawing
    var permitirDedo: Bool
    var alCambiar: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let vista = PKCanvasView()
        vista.drawing = dibujo
        vista.delegate = context.coordinator
        vista.drawingPolicy = permitirDedo ? .anyInput : .pencilOnly
        vista.alwaysBounceVertical = true
        vista.backgroundColor = .clear
        vista.isOpaque = false
        vista.overrideUserInterfaceStyle = .light
        vista.minimumZoomScale = 1
        vista.maximumZoomScale = 3

        context.coordinator.canvas = vista
        // El selector de lápices necesita que la hoja ya esté en pantalla.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.mostrarHerramientas()
        }
        return vista
    }

    func updateUIView(_ vista: PKCanvasView, context: Context) {
        let politica: PKCanvasViewDrawingPolicy = permitirDedo ? .anyInput : .pencilOnly
        if vista.drawingPolicy != politica { vista.drawingPolicy = politica }

        // Solo crece: achicarla saltaría la vista a otro lado mientras escribe.
        let alto = max(vista.bounds.height * 2.5, 1600)
        if vista.contentSize.height < alto {
            vista.contentSize = CGSize(width: vista.bounds.width, height: alto)
        }
    }

    func makeCoordinator() -> Coordinador {
        Coordinador(alCambiar: alCambiar)
    }

    final class Coordinador: NSObject, PKCanvasViewDelegate {
        weak var canvas: PKCanvasView?
        private let selector = PKToolPicker()
        private var tarea: DispatchWorkItem?
        private let alCambiar: (PKDrawing) -> Void

        init(alCambiar: @escaping (PKDrawing) -> Void) {
            self.alCambiar = alCambiar
        }

        func mostrarHerramientas() {
            guard let canvas else { return }
            selector.addObserver(canvas)
            selector.setVisible(true, forFirstResponder: canvas)
            canvas.becomeFirstResponder()
        }

        /// Guarda un segundo y medio después de la última pincelada, no en
        /// cada una: escribir una palabra son veinte trazos.
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            tarea?.cancel()
            let dibujo = canvasView.drawing
            let trabajo = DispatchWorkItem { [weak self] in self?.alCambiar(dibujo) }
            tarea = trabajo
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: trabajo)
        }
    }
}

/// El fondo de la hoja: papel claro con renglones finos.
///
/// Va detrás del lienzo, que es transparente, porque PencilKit no deja poner
/// una imagen de fondo adentro.
struct Papel: View {
    static let color = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let renglon = Color(red: 0.82, green: 0.80, blue: 0.76)

    var body: some View {
        Canvas { contexto, medida in
            contexto.fill(Path(CGRect(origin: .zero, size: medida)),
                          with: .color(Self.color))
            var y: CGFloat = 46
            while y < medida.height {
                let linea = Path { $0.move(to: CGPoint(x: 18, y: y))
                                   $0.addLine(to: CGPoint(x: medida.width - 18, y: y)) }
                contexto.stroke(linea, with: .color(Self.renglon), lineWidth: 0.6)
                y += 34
            }
        }
    }
}

// MARK: - Pasar el dibujo a imagen

enum Tinta {

    /// Convierte lo escrito en una imagen con el papel abajo.
    ///
    /// Recorta a lo que realmente escribió más un margen, así una hoja con
    /// cuatro palabras no sale como una página casi vacía.
    static func imagen(de dibujo: PKDrawing) -> Data? {
        var caja = dibujo.bounds
        guard caja.width > 1, caja.height > 1 else { return nil }
        caja = caja.insetBy(dx: -28, dy: -28)

        let dibujado = dibujo.image(from: caja, scale: 2)
        let marco = CGRect(origin: .zero, size: caja.size)
        let pintor = UIGraphicsImageRenderer(size: caja.size)
        let final = pintor.image { contexto in
            UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1).setFill()
            contexto.fill(marco)
            dibujado.draw(in: marco)
        }
        return final.pngData()
    }
}
