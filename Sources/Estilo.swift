import SwiftUI

/// Las piezas con las que están armadas todas las pantallas.
///
/// **Por qué existe este archivo:** antes cada pantalla usaba `List` y
/// `Section` de iOS, que traen el aspecto que pone Apple por defecto —
/// separadores grises de borde a borde, títulos chiquitos en mayúsculas,
/// filas que se estiran todo el ancho del iPad. Quedaba igual a Ajustes del
/// teléfono y no a esta app.
///
/// Acá está el reemplazo: bloques redondeados con la superficie y el borde de
/// la marca, ancho limitado y centrado, y títulos propios. Las pantallas se
/// escriben con estas piezas y no con las de iOS.
enum Medida {
    /// Más ancho que esto el ojo tiene que viajar demasiado para leer una
    /// fila de punta a punta. Es lo que hace que el iPad no se desarme.
    static let ancho: CGFloat = 760
    static let radio: CGFloat = 18
    static let margen: CGFloat = 18
}

// MARK: - Qué tan adentro estamos

private struct ProfundidadKey: EnvironmentKey { static let defaultValue = 0 }

extension EnvironmentValues {
    /// Cuántas pantallas hay apiladas debajo de esta. Sirve para que una
    /// pantalla sepa si tiene que dibujar su flecha de volver.
    ///
    /// Hace falta porque la barra de navegación de iOS está escondida en toda
    /// la app, así que el botón de volver lo dibujamos nosotros y no hay nadie
    /// que nos diga si hay algo atrás.
    var profundidad: Int {
        get { self[ProfundidadKey.self] }
        set { self[ProfundidadKey.self] = newValue }
    }
}

/// Envuelve el destino de un enlace para que sepa que quedó apilado.
///
/// Todo lo que se abre con `NavigationLink` tiene que ir adentro de esto, o
/// la pantalla nueva no va a mostrar la flecha de volver.
struct Empuje<Contenido: View>: View {
    @Environment(\.profundidad) private var profundidad
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        contenido().environment(\.profundidad, profundidad + 1)
    }
}

// MARK: - El marco de la pantalla

/// El fondo, el encabezado propio y el contenido centrado con tope de ancho.
///
/// **La barra de navegación de iOS está escondida en toda la app.** El título,
/// la flecha de volver y el botón de la derecha los dibuja esta vista, con la
/// tipografía y los colores de la marca, para que el marco no se vea prestado
/// del sistema.
struct Pantalla<Contenido: View>: View {
    var titulo: String? = nil
    var bajada: String? = nil
    var espacio: CGFloat = 18
    /// El botón redondo de la derecha, si la pantalla tiene uno.
    var simbolo: String? = nil
    var accion: (() -> Void)? = nil
    @ViewBuilder var contenido: () -> Contenido

    @Environment(\.profundidad) private var profundidad
    @Environment(\.dismiss) private var volver

    private var hayEncabezado: Bool {
        titulo != nil || profundidad > 0 || accion != nil
    }

    var body: some View {
        ZStack {
            Paleta.fondo.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: espacio) {
                    if hayEncabezado { encabezado }
                    contenido()
                }
                .padding(.horizontal, Medida.margen)
                .padding(.top, 12)
                .padding(.bottom, 34)
                .frame(maxWidth: Medida.ancho)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var encabezado: some View {
        HStack(alignment: .center, spacing: 13) {
            if profundidad > 0 {
                BotonRedondo(simbolo: "chevron.left") { volver() }
            }
            VStack(alignment: .leading, spacing: 3) {
                if let titulo {
                    Text(titulo)
                        .font(.system(size: 29, weight: .bold))
                        .foregroundColor(Paleta.texto)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if let bajada {
                    Text(bajada)
                        .font(.system(size: 13))
                        .foregroundColor(Paleta.suave)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if let simbolo, let accion {
                BotonRedondo(simbolo: simbolo, accion: accion)
            }
        }
        .padding(.bottom, 2)
    }
}

/// El botón circular del encabezado: volver, agregar, reconectar.
struct BotonRedondo: View {
    let simbolo: String
    var destacado = false
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: simbolo)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(destacado ? .white : Paleta.texto)
                .frame(width: 40, height: 40)
                .background(Circle().fill(destacado ? Paleta.acento : Paleta.superficie))
                .overlay(Circle().stroke(destacado ? Color.clear : Paleta.borde, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bloques y rótulos

/// Un bloque de filas: tarjeta redondeada con la superficie de la marca.
struct Bloque<Contenido: View>: View {
    var titulo: String? = nil
    var pie: String? = nil
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let titulo { Rotulo(titulo) }
            VStack(spacing: 0) { contenido() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Medida.radio, style: .continuous)
                    .fill(Paleta.superficie))
                .overlay(RoundedRectangle(cornerRadius: Medida.radio, style: .continuous)
                    .stroke(Paleta.borde, lineWidth: 1))
            if let pie {
                Text(pie)
                    .font(.system(size: 12))
                    .foregroundColor(Paleta.suave)
                    .padding(.horizontal, 4)
                    .padding(.top, 1)
            }
        }
    }
}

/// El título de un bloque. A propósito **no** va en mayúsculas chiquitas
/// como los de iOS: va en el mismo peso que los títulos de las fichas.
struct Rotulo: View {
    let texto: String

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(texto)
            .font(.system(size: 13, weight: .semibold))
            .tracking(0.3)
            .foregroundColor(Paleta.texto.opacity(0.78))
            .padding(.horizontal, 4)
    }
}

/// La línea fina que separa dos filas dentro de un bloque.
struct Linea: View {
    var body: some View {
        Rectangle()
            .fill(Paleta.borde)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}

// MARK: - Filas

/// Nombre a la izquierda, valor a la derecha.
struct Fila: View {
    let titulo: String
    let valor: String
    var resaltado = false

    init(_ titulo: String, _ valor: String, resaltado: Bool = false) {
        self.titulo = titulo
        self.valor = valor
        self.resaltado = resaltado
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(titulo)
                .font(.system(size: 15))
                .foregroundColor(Paleta.suave)
            Spacer(minLength: 8)
            Text(valor)
                .font(.system(size: 15, weight: resaltado ? .semibold : .medium))
                .monospacedDigit()
                .foregroundColor(resaltado ? Paleta.acento : Paleta.texto)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// Una fila que hace algo al tocarla.
struct Accion: View {
    let texto: String
    var simbolo: String? = nil
    var destructiva = false
    var apagada = false
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 11) {
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 18)
                }
                Text(texto)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
            }
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(apagada)
    }

    private var color: Color {
        if apagada { return Paleta.suave }
        return destructiva ? Color(red: 0.86, green: 0.35, blue: 0.35) : Paleta.acento
    }
}

/// Una fila que abre otra pantalla.
struct Navega<Destino: View>: View {
    let texto: String
    var simbolo: String? = nil
    var detalle: String? = nil
    @ViewBuilder var destino: () -> Destino

    var body: some View {
        NavigationLink {
            Empuje { destino() }
        } label: {
            HStack(spacing: 11) {
                if let simbolo {
                    Image(systemName: simbolo)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Paleta.acento)
                        .frame(width: 18)
                }
                Text(texto)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Paleta.texto)
                Spacer(minLength: 8)
                if let detalle {
                    Text(detalle)
                        .font(.system(size: 14))
                        .foregroundColor(Paleta.suave)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Paleta.suave)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Lo que dice un bloque cuando todavía no hay nada que mostrar.
struct Vacio: View {
    let texto: String

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        Text(texto)
            .font(.system(size: 14))
            .foregroundColor(Paleta.suave)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
    }
}

/// Envuelve una fila cualquiera para que tenga el mismo margen que las demás.
struct Celda<Contenido: View>: View {
    var alto: CGFloat? = nil
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        contenido()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(height: alto)
    }
}

// MARK: - Números sueltos

/// Un número con su rótulo, para las grillas de la semana.
struct Dato: View {
    let valor: String
    let rotulo: String
    var detalle: String? = nil
    var color: Color = Paleta.texto

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(valor)
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(rotulo)
                .font(.system(size: 13))
                .foregroundColor(Paleta.texto.opacity(0.8))
            if let detalle {
                Text(detalle)
                    .font(.system(size: 11))
                    .foregroundColor(Paleta.suave)
                    .lineLimit(2)
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(minHeight: 104, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Paleta.superficie))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Paleta.borde, lineWidth: 1))
    }
}

/// El verde y el rojo de las comparaciones, iguales en toda la app.
enum Tono {
    static let bien = Color(red: 0.26, green: 0.78, blue: 0.47)
    static let mal = Color(red: 0.86, green: 0.42, blue: 0.38)

    /// Verde si subió, rojo si bajó. `alReves` para los casos donde bajar
    /// es lo bueno, como los gastos.
    static func segun(_ cambio: Double, alReves: Bool = false) -> Color {
        if abs(cambio) < 0.0001 { return Paleta.texto }
        let positivo = cambio > 0
        return (positivo != alReves) ? bien : mal
    }
}

// MARK: - Recorrer listas con su posición

/// Un elemento de una lista junto con su posición.
///
/// Sirve para dibujar la línea separadora **entre** filas y no antes de la
/// primera: `ForEach(enumerar(lista))` y después `if fila.puesto > 0 { Linea() }`.
struct Enumerada<Valor>: Identifiable {
    let id: Int
    let valor: Valor
    var puesto: Int { id }
}

func enumerar<Valor>(_ lista: [Valor]) -> [Enumerada<Valor>] {
    lista.enumerated().map { Enumerada(id: $0.offset, valor: $0.element) }
}

// MARK: - Números

/// Kilos sin decimales de más: 40 en vez de 40,0 pero 2,5 cuando hace falta.
enum Kilos {
    static func texto(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    /// Con separador de miles, para los volúmenes que llegan a cinco cifras.
    static func grande(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }
}

/// Varias filas de nombre y valor, con las líneas puestas entre medio.
///
/// Además de ahorrar repetición, evita el tope de diez vistas que tiene
/// SwiftUI dentro de un bloque.
struct Filas: View {
    let pares: [(String, String)]

    init(_ pares: [(String, String)]) { self.pares = pares }

    var body: some View {
        ForEach(enumerar(pares)) { fila in
            if fila.puesto > 0 { Linea() }
            Fila(fila.valor.0, fila.valor.1)
        }
    }
}

// MARK: - Avance contra un objetivo

/// Una barra de avance con su rótulo. Se usa cuando hay un objetivo cargado.
///
/// `alReves` es para los gastos: ahí llenar la barra no es un logro, así que
/// pasarse del tope la pone roja en vez de verde.
struct Progreso: View {
    let rotulo: String
    let hecho: Double
    let meta: Double
    var unidad: String = ""
    var alReves = false

    private var parte: Double {
        guard meta > 0 else { return 0 }
        return min(1, max(0, hecho / meta))
    }

    private var listo: Bool { meta > 0 && hecho >= meta }

    private var color: Color {
        if alReves { return listo ? Tono.mal : Paleta.acento }
        return listo ? Tono.bien : Paleta.acento
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(rotulo)
                    .font(.system(size: 15))
                    .foregroundColor(Paleta.texto)
                Spacer(minLength: 8)
                Text(numero(hecho) + " / " + numero(meta) + unidad)
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(listo ? color : Paleta.texto)
            }
            GeometryReader { espacio in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Paleta.borde)
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: max(parte > 0 ? 6 : 0, espacio.size.width * parte),
                               height: 6)
                }
            }
            .frame(height: 6)
            Text(falta)
                .font(.system(size: 11))
                .foregroundColor(Paleta.suave)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var falta: String {
        guard meta > 0 else { return "" }
        if listo {
            return alReves ? "Te pasaste por " + numero(hecho - meta) + unidad
                           : "Cumplido"
        }
        return "Faltan " + numero(meta - hecho) + unidad
    }

    /// Entero cuando es redondo, con un decimal cuando no, y con separador de
    /// miles para que 6000 se lea 6.000.
    private func numero(_ v: Double) -> String {
        v == v.rounded() ? Kilos.grande(v) : String(format: "%.1f", v)
    }
}

// MARK: - Buscar

/// El casillero de búsqueda, en lugar del `searchable` del sistema.
///
/// El del sistema aparece y desaparece solo arriba de todo, con su fondo gris
/// y su lupa, y es de las cosas que más gritan "iOS". Este vive adentro de la
/// pantalla, como un bloque más.
struct Buscador: View {
    @Binding var texto: String
    var invitacion = "Buscar"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Paleta.suave)
            TextField(invitacion, text: $texto)
                .font(.system(size: 16))
                .foregroundColor(Paleta.texto)
                .autocorrectionDisabled()
            if !texto.isEmpty {
                Button { texto = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Paleta.suave)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Paleta.superficie))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Paleta.borde, lineWidth: 1))
    }
}

// MARK: - Ventanas propias

/// El marco de todo lo que se abre encima: anotar una serie, corregir un
/// gasto, escribir una nota.
///
/// Reemplaza al `NavigationStack` con botones de "Cancelar" y "Guardar" en la
/// barra azul del sistema. Acá la cruz y el botón de confirmar son nuestros.
struct Hoja<Contenido: View>: View {
    let titulo: String
    var bajada: String? = nil
    var confirmar: String? = nil
    var puedeConfirmar = true
    var alConfirmar: (() -> Void)? = nil
    @ViewBuilder var contenido: () -> Contenido

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        ZStack {
            Paleta.fondo.ignoresSafeArea()
            VStack(spacing: 0) {
                barra
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        contenido()
                    }
                    .padding(.horizontal, Medida.margen)
                    .padding(.top, 4)
                    .padding(.bottom, 34)
                    .frame(maxWidth: Medida.ancho)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var barra: some View {
        HStack(alignment: .center, spacing: 12) {
            BotonRedondo(simbolo: "xmark") { cerrar() }
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Paleta.texto)
                    .lineLimit(1)
                if let bajada {
                    Text(bajada)
                        .font(.system(size: 12))
                        .foregroundColor(Paleta.suave)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if let confirmar, let alConfirmar {
                Button {
                    alConfirmar()
                    cerrar()
                } label: {
                    Text(confirmar)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(Paleta.acento))
                }
                .buttonStyle(.plain)
                .opacity(puedeConfirmar ? 1 : 0.4)
                .disabled(!puedeConfirmar)
            }
        }
        .padding(.horizontal, Medida.margen)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(maxWidth: Medida.ancho)
        .frame(maxWidth: .infinity)
        .background(Paleta.fondo)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Paleta.borde).frame(height: 1)
        }
    }
}

// MARK: - Elegir de una lista

/// La fila que muestra qué está elegido y abre la lista al tocarla.
///
/// Reemplaza al `Menu` de iOS, que despliega el globito gris del sistema.
struct Elegido: View {
    let rotulo: String
    let valor: String
    var vacio = false
    let tocar: () -> Void

    var body: some View {
        Button(action: tocar) {
            HStack {
                Text(rotulo)
                    .font(.system(size: 15))
                    .foregroundColor(Paleta.suave)
                Spacer(minLength: 10)
                Text(valor)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(vacio ? Paleta.suave : Paleta.acento)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Paleta.suave)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// La lista para elegir una opción, en una ventana propia.
struct Eleccion: View {
    let titulo: String
    let opciones: [String]
    /// Si viene, se agrega arriba de todo como opción vacía ("Sin carpeta").
    var ninguna: String? = nil
    let elegida: String
    let elegir: (String) -> Void

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        Hoja(titulo: titulo) {
            Bloque {
                if let ninguna {
                    opcion(texto: ninguna, valor: "", primera: true)
                }
                ForEach(enumerar(opciones)) { fila in
                    if fila.puesto > 0 || ninguna != nil { Linea() }
                    opcion(texto: fila.valor, valor: fila.valor, primera: false)
                }
            }
        }
    }

    private func opcion(texto: String, valor: String, primera: Bool) -> some View {
        Button {
            elegir(valor)
            cerrar()
        } label: {
            HStack {
                Text(texto)
                    .font(.system(size: 16))
                    .foregroundColor(valor.isEmpty ? Paleta.suave : Paleta.texto)
                Spacer()
                if elegida == valor {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Paleta.acento)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Carpetas

/// La tarjeta de una carpeta, con su nombre y cuántas cosas tiene adentro.
/// La usan las notas y la libreta.
struct FichaDeCarpeta: View {
    let nombre: String
    let cuantas: Int
    var simbolo = "folder"
    var acento = true
    var unidad = "nota"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: simbolo)
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(acento ? Paleta.acento : Paleta.suave)
            Spacer(minLength: 10)
            Text(nombre)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Paleta.texto)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.85)
            Text(cuantas == 1 ? "1 \(unidad)" : "\(cuantas) \(unidad)s")
                .font(.system(size: 11.5))
                .foregroundColor(Paleta.suave)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Medida.radio, style: .continuous)
            .fill(Paleta.superficie))
        .overlay(RoundedRectangle(cornerRadius: Medida.radio, style: .continuous)
            .stroke(Paleta.borde, lineWidth: 1))
    }
}
