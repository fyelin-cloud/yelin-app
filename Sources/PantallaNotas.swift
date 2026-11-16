import SwiftUI

/// Qué conjunto de notas se está mirando.
enum VistaDeNotas: Hashable {
    case carpeta(String)
    case sinCarpeta
    case importantes
    case todas

    var titulo: String {
        switch self {
        case .carpeta(let nombre): return nombre
        case .sinCarpeta:          return "Sin carpeta"
        case .importantes:         return "Importantes"
        case .todas:               return "Todas"
        }
    }

    var simbolo: String {
        switch self {
        case .carpeta:     return "folder"
        case .sinCarpeta:  return "tray"
        case .importantes: return "star"
        case .todas:       return "note.text"
        }
    }

    /// La carpeta en la que cae una nota nueva creada desde acá.
    var carpetaParaNuevas: String {
        if case .carpeta(let nombre) = self { return nombre }
        return ""
    }
}

/// Las notas, separadas en carpetas.
///
/// La pantalla de arriba muestra las carpetas; cada una se abre aparte. La
/// búsqueda, en cambio, cruza todo: buscar no tiene por qué respetar dónde
/// quedó guardada una nota.
struct PantallaNotas: View {
    @ObservedObject var diario: Diario

    @State private var busqueda = ""
    @State private var escribiendo = false
    @State private var enEdicion: Nota?

    @Environment(\.horizontalSizeClass) private var anchoDePantalla

    private var buscando: Bool {
        !busqueda.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var columnas: [GridItem] {
        let cuantas = anchoDePantalla == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: cuantas)
    }

    var body: some View {
        Pantalla {
            if buscando {
                resultados
            } else {
                carpetas
                ultimas
                Bloque {
                    Navega(texto: "Administrar carpetas", simbolo: "folder.badge.gearshape",
                           detalle: "\(diario.carpetas.count)") {
                        PantallaCarpetas(diario: diario)
                    }
                }
            }
        }
        .searchable(text: $busqueda, prompt: "Buscar en todas las notas")
        .navigationTitle("Notas")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { escribiendo = true } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $escribiendo) {
            EditorDeNota(titulo: "Nota nueva", texto: "", importante: false,
                         carpeta: "", carpetas: diario.carpetas) { texto, importante, carpeta in
                diario.guardarNota(texto: texto, importante: importante, carpeta: carpeta)
            }
        }
        .sheet(item: $enEdicion) { nota in
            EditorDeNota(titulo: "Nota", texto: nota.texto, importante: nota.importante,
                         carpeta: nota.carpeta, carpetas: diario.carpetas) { texto, importante, carpeta in
                diario.reemplazar(nota, texto: texto, importante: importante, carpeta: carpeta)
            }
        }
    }

    // MARK: Las carpetas

    private var carpetas: some View {
        LazyVGrid(columns: columnas, spacing: 12) {
            ForEach(diario.carpetas, id: \.self) { nombre in
                NavigationLink {
                    PantallaCarpeta(diario: diario, vista: .carpeta(nombre))
                } label: {
                    Carpeta(nombre: nombre, cuantas: diario.cuantasEn(nombre),
                            simbolo: "folder", acento: true)
                }
                .buttonStyle(.plain)
            }

            if diario.sinCarpeta > 0 {
                NavigationLink {
                    PantallaCarpeta(diario: diario, vista: .sinCarpeta)
                } label: {
                    Carpeta(nombre: "Sin carpeta", cuantas: diario.sinCarpeta,
                            simbolo: "tray", acento: false)
                }
                .buttonStyle(.plain)
            }

            let marcadas = diario.notas.filter(\.importante).count
            if marcadas > 0 {
                NavigationLink {
                    PantallaCarpeta(diario: diario, vista: .importantes)
                } label: {
                    Carpeta(nombre: "Importantes", cuantas: marcadas,
                            simbolo: "star.fill", acento: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Las últimas, de cualquier carpeta

    private var ultimas: some View {
        Bloque(titulo: "Últimas",
               pie: diario.notas.isEmpty ? nil
                  : "De cualquier carpeta. Tocá una para abrirla.") {
            if diario.notas.isEmpty {
                Vacio("Todavía no hay notas. El lápiz de arriba a la derecha "
                      + "escribe la primera.")
            } else {
                ForEach(enumerar(Array(diario.notas.prefix(6)))) { fila in
                    if fila.puesto > 0 { Linea() }
                    RenglonDeNota(nota: fila.valor, diario: diario,
                                  mostrarCarpeta: true) { enEdicion = fila.valor }
                }
            }
        }
    }

    // MARK: Buscando

    private var resultados: some View {
        let encontradas = diario.notasQueCoinciden(con: busqueda)
        return Bloque(titulo: encontradas.isEmpty ? "Sin resultados"
                                                  : "\(encontradas.count) encontradas") {
            if encontradas.isEmpty {
                Vacio("Ninguna nota dice eso.")
            } else {
                ForEach(enumerar(encontradas)) { fila in
                    if fila.puesto > 0 { Linea() }
                    RenglonDeNota(nota: fila.valor, diario: diario,
                                  mostrarCarpeta: true) { enEdicion = fila.valor }
                }
            }
        }
    }
}

/// Una carpeta en la grilla.
private struct Carpeta: View {
    let nombre: String
    let cuantas: Int
    let simbolo: String
    let acento: Bool

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
            Text(cuantas == 1 ? "1 nota" : "\(cuantas) notas")
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

// MARK: - Lo de adentro de una carpeta

struct PantallaCarpeta: View {
    @ObservedObject var diario: Diario
    let vista: VistaDeNotas

    @State private var escribiendo = false
    @State private var enEdicion: Nota?

    private var lista: [Nota] {
        switch vista {
        case .carpeta(let nombre): return diario.notas(en: nombre)
        case .sinCarpeta:          return diario.notas(en: nil)
        case .importantes:         return diario.notas.filter(\.importante)
        case .todas:               return diario.notas
        }
    }

    var body: some View {
        Pantalla(titulo: vista.titulo, bajada: bajada) {
            Bloque(pie: lista.isEmpty ? nil
                      : "Tocá una nota para editarla. Mantené apretada para "
                      + "moverla de carpeta o borrarla.") {
                if lista.isEmpty {
                    Vacio(vacia)
                } else {
                    ForEach(enumerar(lista)) { fila in
                        if fila.puesto > 0 { Linea() }
                        RenglonDeNota(nota: fila.valor, diario: diario,
                                      mostrarCarpeta: mostrarCarpeta) {
                            enEdicion = fila.valor
                        }
                    }
                }
            }
        }
        .navigationTitle(vista.titulo)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { escribiendo = true } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $escribiendo) {
            EditorDeNota(titulo: "Nota nueva", texto: "",
                         importante: vista == .importantes,
                         carpeta: vista.carpetaParaNuevas,
                         carpetas: diario.carpetas) { texto, importante, carpeta in
                diario.guardarNota(texto: texto, importante: importante, carpeta: carpeta)
            }
        }
        .sheet(item: $enEdicion) { nota in
            EditorDeNota(titulo: "Nota", texto: nota.texto, importante: nota.importante,
                         carpeta: nota.carpeta, carpetas: diario.carpetas) { texto, importante, carpeta in
                diario.reemplazar(nota, texto: texto, importante: importante, carpeta: carpeta)
            }
        }
    }

    private var mostrarCarpeta: Bool {
        if case .carpeta = vista { return false }
        return vista != .sinCarpeta
    }

    private var bajada: String? {
        lista.isEmpty ? nil : (lista.count == 1 ? "1 nota" : "\(lista.count) notas")
    }

    private var vacia: String {
        switch vista {
        case .carpeta:     return "Esta carpeta está vacía."
        case .sinCarpeta:  return "Todas las notas están en alguna carpeta."
        case .importantes: return "Todavía no marcaste ninguna como importante."
        case .todas:       return "Todavía no hay notas."
        }
    }
}

/// Un renglón de nota, con lo que se puede hacer al mantenerlo apretado.
private struct RenglonDeNota: View {
    let nota: Nota
    @ObservedObject var diario: Diario
    var mostrarCarpeta: Bool
    let abrir: () -> Void

    var body: some View {
        Button(action: abrir) {
            HStack(alignment: .top, spacing: 10) {
                if nota.importante {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Paleta.acento)
                        .padding(.top, 5)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(nota.titulo)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Paleta.texto)
                        .lineLimit(1)
                    if !nota.resto.isEmpty {
                        Text(nota.resto)
                            .font(.system(size: 13))
                            .foregroundColor(Paleta.suave)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 6) {
                        if mostrarCarpeta && !nota.carpeta.isEmpty {
                            Text(nota.carpeta)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Paleta.acento)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Paleta.acento.opacity(0.15)))
                        }
                        Text(nota.instante.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundColor(Paleta.suave.opacity(0.85))
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Menu {
                ForEach(diario.carpetas, id: \.self) { nombre in
                    Button {
                        diario.mover(nota, a: nombre)
                    } label: {
                        if nota.carpeta == nombre {
                            Label(nombre, systemImage: "checkmark")
                        } else {
                            Text(nombre)
                        }
                    }
                }
                if !nota.carpeta.isEmpty {
                    Divider()
                    Button { diario.mover(nota, a: "") } label: {
                        Label("Sacar de la carpeta", systemImage: "tray")
                    }
                }
            } label: {
                Label("Mover a", systemImage: "folder")
            }
            Button(role: .destructive) {
                diario.borrar(nota)
            } label: {
                Label("Borrar la nota", systemImage: "trash")
            }
        }
    }
}

// MARK: - Administrar carpetas

struct PantallaCarpetas: View {
    @ObservedObject var diario: Diario

    @State private var nueva = ""
    @State private var renombrando: String?
    @State private var nombreNuevo = ""

    var body: some View {
        Pantalla(titulo: "Carpetas",
                 bajada: "Para separar las notas por materia o por tema") {
            Bloque(titulo: "Agregar") {
                HStack(spacing: 10) {
                    TextField("Nombre de la carpeta", text: $nueva)
                        .font(.system(size: 16))
                        .foregroundColor(Paleta.texto)
                        .submitLabel(.done)
                        .onSubmit(agregar)
                    Button(action: agregar) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Paleta.acento))
                    }
                    .buttonStyle(.plain)
                    .opacity(nueva.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Bloque(titulo: "Las que tenés",
                   pie: "Mantené apretada una para renombrarla o sacarla. Sacar una "
                      + "carpeta no borra sus notas: quedan sin carpeta.") {
                if diario.carpetas.isEmpty {
                    Vacio("No quedó ninguna.")
                } else {
                    ForEach(enumerar(diario.carpetas)) { fila in
                        if fila.puesto > 0 { Linea() }
                        Celda {
                            HStack(spacing: 11) {
                                Image(systemName: "folder")
                                    .font(.system(size: 14))
                                    .foregroundColor(Paleta.acento)
                                    .frame(width: 18)
                                Text(fila.valor)
                                    .font(.system(size: 15))
                                    .foregroundColor(Paleta.texto)
                                Spacer()
                                Text("\(diario.cuantasEn(fila.valor))")
                                    .font(.system(size: 14))
                                    .monospacedDigit()
                                    .foregroundColor(Paleta.suave)
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                nombreNuevo = fila.valor
                                renombrando = fila.valor
                            } label: {
                                Label("Renombrar", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                diario.borrarCarpeta(fila.valor)
                            } label: {
                                Label("Sacar la carpeta", systemImage: "folder.badge.minus")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Carpetas")
        .alert("Renombrar la carpeta", isPresented: Binding(
            get: { renombrando != nil },
            set: { if !$0 { renombrando = nil } })) {
            TextField("Nombre", text: $nombreNuevo)
            Button("Cancelar", role: .cancel) { renombrando = nil }
            Button("Guardar") {
                if let vieja = renombrando { diario.renombrarCarpeta(vieja, a: nombreNuevo) }
                renombrando = nil
            }
        } message: {
            Text("Las notas que estén adentro se mueven con ella.")
        }
    }

    private func agregar() {
        diario.agregarCarpeta(nueva)
        nueva = ""
    }
}

// MARK: - El editor

struct EditorDeNota: View {
    let titulo: String
    @State var texto: String
    @State var importante: Bool
    @State var carpeta: String
    let carpetas: [String]
    let guardar: (String, Bool, String) -> Void

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            ZStack {
                Paleta.fondo.ignoresSafeArea()
                VStack(spacing: 0) {
                    TextEditor(text: $texto)
                        .font(.system(size: 16))
                        .scrollContentBackground(.hidden)
                        .background(Paleta.fondo)
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                    Rectangle().fill(Paleta.borde).frame(height: 1)

                    HStack {
                        Text("Carpeta")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Paleta.texto)
                        Spacer()
                        Menu {
                            Button("Sin carpeta") { carpeta = "" }
                            ForEach(carpetas, id: \.self) { nombre in
                                Button(nombre) { carpeta = nombre }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(carpeta.isEmpty ? "Sin carpeta" : carpeta)
                                    .font(.system(size: 15))
                                    .foregroundColor(carpeta.isEmpty ? Paleta.suave : Paleta.acento)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Paleta.suave)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)

                    Rectangle().fill(Paleta.borde).frame(height: 1)

                    Toggle("Importante", isOn: $importante)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Paleta.texto)
                        .tint(Paleta.acento)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                }
            }
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guardar(texto, importante, carpeta)
                        cerrar()
                    }
                    .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
