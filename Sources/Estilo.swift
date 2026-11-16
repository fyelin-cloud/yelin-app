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

// MARK: - El marco de la pantalla

/// El fondo, el título grande y el contenido centrado con tope de ancho.
struct Pantalla<Contenido: View>: View {
    var titulo: String? = nil
    var bajada: String? = nil
    var espacio: CGFloat = 18
    @ViewBuilder var contenido: () -> Contenido

    var body: some View {
        ZStack {
            Paleta.fondo.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: espacio) {
                    if let titulo {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(titulo)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(Paleta.texto)
                            if let bajada {
                                Text(bajada)
                                    .font(.system(size: 13))
                                    .foregroundColor(Paleta.suave)
                            }
                        }
                        .padding(.bottom, 2)
                    }
                    contenido()
                }
                .padding(.horizontal, Medida.margen)
                .padding(.top, 10)
                .padding(.bottom, 34)
                .frame(maxWidth: Medida.ancho)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
            destino()
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

    private func numero(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}
