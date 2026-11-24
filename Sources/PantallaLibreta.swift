import SwiftUI
import PencilKit

/// La libreta: hojas escritas a mano, en las mismas carpetas que las notas.
///
/// Comparte las carpetas con las notas a propósito: así "Finanzas II" junta
/// lo tipeado y lo manuscrito en un solo lugar, que es como uno piensa una
/// materia.
struct PantallaLibreta: View {
    @ObservedObject var libreta: Libreta
    @ObservedObject var diario: Diario

    @State private var busqueda = ""
    @State private var abriendo: Pagina?

    @Environment(\.horizontalSizeClass) private var anchoDePantalla

    private var buscando: Bool {
        !busqueda.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var columnas: [GridItem] {
        let cuantas = anchoDePantalla == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: cuantas)
    }

    var body: some View {
        Pantalla(titulo: "Libreta",
                 bajada: "Escrita a mano con el Pencil",
                 simbolo: "plus",
                 accion: { abriendo = libreta.crear(en: "") }) {
            Buscador(texto: $busqueda, invitacion: "Buscar una hoja")

            if buscando {
                resultados
            } else {
                carpetas
                ultimas
            }
        }
        .fullScreenCover(item: $abriendo) { hoja in
            PantallaPagina(libreta: libreta, pagina: hoja, carpetas: diario.carpetas)
        }
    }

    private var carpetas: some View {
        LazyVGrid(columns: columnas, spacing: 12) {
            ForEach(diario.carpetas, id: \.self) { nombre in
                NavigationLink {
                    Empuje {
                        CarpetaDeLibreta(libreta: libreta, diario: diario, carpeta: nombre)
                    }
                } label: {
                    FichaDeCarpeta(nombre: nombre, cuantas: libreta.cuantasEn(nombre),
                                   unidad: "hoja")
                }
                .buttonStyle(.plain)
            }
            if libreta.sinCarpeta > 0 {
                NavigationLink {
                    Empuje {
                        CarpetaDeLibreta(libreta: libreta, diario: diario, carpeta: nil)
                    }
                } label: {
                    FichaDeCarpeta(nombre: "Sin carpeta", cuantas: libreta.sinCarpeta,
                                   simbolo: "tray", acento: false, unidad: "hoja")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ultimas: some View {
        Bloque(titulo: "Últimas",
               pie: libreta.paginas.isEmpty ? nil
                  : "Tocá una para seguir escribiendo.") {
            if libreta.paginas.isEmpty {
                Vacio("Todavía no hay ninguna hoja. El más de arriba abre la primera.")
            } else {
                ForEach(enumerar(Array(libreta.paginas.prefix(8)))) { fila in
                    if fila.puesto > 0 { Linea() }
                    RenglonDePagina(libreta: libreta, pagina: fila.valor,
                                    carpetas: diario.carpetas,
                                    mostrarCarpeta: true) { abriendo = fila.valor }
                }
            }
        }
    }

    private var resultados: some View {
        let encontradas = libreta.coinciden(con: busqueda)
        return Bloque(titulo: encontradas.isEmpty ? "Sin resultados"
                                                  : "\(encontradas.count) encontradas") {
            if encontradas.isEmpty {
                Vacio("Ninguna hoja se llama así.")
            } else {
                ForEach(enumerar(encontradas)) { fila in
                    if fila.puesto > 0 { Linea() }
                    RenglonDePagina(libreta: libreta, pagina: fila.valor,
                                    carpetas: diario.carpetas,
                                    mostrarCarpeta: true) { abriendo = fila.valor }
                }
            }
        }
    }
}

// MARK: - Una carpeta de la libreta

struct CarpetaDeLibreta: View {
    @ObservedObject var libreta: Libreta
    @ObservedObject var diario: Diario
    let carpeta: String?

    @State private var abriendo: Pagina?

    private var lista: [Pagina] { libreta.paginas(en: carpeta) }
    private var titulo: String { carpeta ?? "Sin carpeta" }

    var body: some View {
        Pantalla(titulo: titulo,
                 bajada: lista.isEmpty ? nil
                       : (lista.count == 1 ? "1 hoja" : "\(lista.count) hojas"),
                 simbolo: "plus",
                 accion: { abriendo = libreta.crear(en: carpeta ?? "") }) {
            Bloque(pie: lista.isEmpty ? nil
                      : "Mantené apretada una hoja para moverla o borrarla.") {
                if lista.isEmpty {
                    Vacio("Esta carpeta no tiene hojas todavía.")
                } else {
                    ForEach(enumerar(lista)) { fila in
                        if fila.puesto > 0 { Linea() }
                        RenglonDePagina(libreta: libreta, pagina: fila.valor,
                                        carpetas: diario.carpetas,
                                        mostrarCarpeta: false) { abriendo = fila.valor }
                    }
                }
            }
        }
        .fullScreenCover(item: $abriendo) { hoja in
            PantallaPagina(libreta: libreta, pagina: hoja, carpetas: diario.carpetas)
        }
    }
}

/// Un renglón con la miniatura de lo escrito.
private struct RenglonDePagina: View {
    @ObservedObject var libreta: Libreta
    let pagina: Pagina
    let carpetas: [String]
    let mostrarCarpeta: Bool
    let abrir: () -> Void

    @State private var moviendo = false

    var body: some View {
        Button(action: abrir) {
            HStack(spacing: 13) {
                miniatura
                VStack(alignment: .leading, spacing: 3) {
                    Text(pagina.nombreVisible)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Paleta.texto)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if mostrarCarpeta && !pagina.carpeta.isEmpty {
                            Text(pagina.carpeta)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Paleta.acento)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Paleta.acento.opacity(0.15)))
                        }
                        Text(Fechas.conHora(pagina.modificada))
                            .font(.system(size: 11))
                            .foregroundColor(Paleta.suave)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Paleta.suave)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { moviendo = true } label: {
                Label("Mover a otra carpeta", systemImage: "folder")
            }
            Button(role: .destructive) {
                libreta.borrar(pagina)
            } label: {
                Label("Borrar la hoja", systemImage: "trash")
            }
        }
        .sheet(isPresented: $moviendo) {
            Eleccion(titulo: "Mover la hoja", opciones: carpetas,
                     ninguna: "Sin carpeta", elegida: pagina.carpeta) {
                libreta.mover(pagina, a: $0)
            }
        }
    }

    @ViewBuilder
    private var miniatura: some View {
        let marco = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if libreta.hayImagen(pagina.id),
           let imagen = UIImage(contentsOfFile: libreta.imagenDe(pagina.id).path) {
            Image(uiImage: imagen)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 58, height: 44)
                .clipShape(marco)
                .overlay(marco.stroke(Paleta.borde, lineWidth: 1))
                .id(pagina.modificada)
        } else {
            marco
                .fill(Papel.color.opacity(0.18))
                .frame(width: 58, height: 44)
                .overlay(marco.stroke(Paleta.borde, lineWidth: 1))
                .overlay(
                    Image(systemName: "pencil.line")
                        .font(.system(size: 15))
                        .foregroundColor(Paleta.suave)
                )
        }
    }
}

// MARK: - La hoja abierta

/// La hoja a pantalla completa. Acá no se usa `Pantalla` porque el lienzo
/// necesita todo el alto y no puede ir adentro de algo que ya scrollea.
struct PantallaPagina: View {
    @ObservedObject var libreta: Libreta
    let pagina: Pagina
    let carpetas: [String]

    @State private var dibujo = PKDrawing()
    @State private var titulo = ""
    @State private var carpeta = ""
    @State private var conDedo = false
    @State private var eligiendo = false
    @State private var cargado = false
    @State private var guardado = Date()

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        ZStack {
            Paleta.fondo.ignoresSafeArea()
            VStack(spacing: 0) {
                barra
                ZStack {
                    Papel()
                    Lienzo(dibujo: $dibujo, permitirDedo: conDedo) { nuevo in
                        guardar(nuevo)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Paleta.borde, lineWidth: 1))
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .onAppear(perform: preparar)
        .onDisappear { guardar(dibujo) }
        .sheet(isPresented: $eligiendo) {
            Eleccion(titulo: "Carpeta", opciones: carpetas,
                     ninguna: "Sin carpeta", elegida: carpeta) { elegida in
                carpeta = elegida
                libreta.mover(pagina, a: elegida)
            }
        }
    }

    private var barra: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                BotonRedondo(simbolo: "chevron.left") {
                    guardar(dibujo)
                    cerrar()
                }
                TextField("Ponele un nombre", text: $titulo)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Paleta.texto)
                    .submitLabel(.done)
                    .onSubmit { libreta.renombrar(pagina, a: titulo) }
                Spacer(minLength: 0)
                BotonRedondo(simbolo: conDedo ? "hand.draw.fill" : "hand.draw",
                             destacado: conDedo) {
                    conDedo.toggle()
                }
                if libreta.hayImagen(pagina.id) {
                    ShareLink(item: libreta.imagenDe(pagina.id)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Paleta.texto)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Paleta.superficie))
                            .overlay(Circle().stroke(Paleta.borde, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Button { eligiendo = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .medium))
                        Text(carpeta.isEmpty ? "Sin carpeta" : carpeta)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(carpeta.isEmpty ? Paleta.suave : Paleta.acento)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Paleta.superficie))
                    .overlay(Capsule().stroke(Paleta.borde, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Text(conDedo ? "Se puede escribir con el dedo"
                             : "Solo con el Pencil, para no rayarla con la mano")
                    .font(.system(size: 11))
                    .foregroundColor(Paleta.suave)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private func preparar() {
        guard !cargado else { return }
        cargado = true
        titulo = pagina.titulo
        carpeta = pagina.carpeta
        if let datos = libreta.dibujoDe(pagina.id),
           let guardado = try? PKDrawing(data: datos) {
            dibujo = guardado
        }
    }

    private func guardar(_ nuevo: PKDrawing) {
        dibujo = nuevo
        libreta.guardarDibujo(nuevo.dataRepresentation(),
                              imagen: Tinta.imagen(de: nuevo),
                              de: pagina.id)
        if titulo != pagina.titulo { libreta.renombrar(pagina, a: titulo) }
        guardado = Date()
    }
}
