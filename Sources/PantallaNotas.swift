import SwiftUI

/// Notas sueltas con fecha. Las importantes van arriba.
struct PantallaNotas: View {
    @ObservedObject var diario: Diario

    @State private var escribiendo = false
    @State private var enEdicion: Nota?
    @State private var busqueda = ""

    private var lista: [Nota] { diario.notasQueCoinciden(con: busqueda) }

    var body: some View {
        List {
            if lista.isEmpty {
                Text(busqueda.isEmpty ? "Todavía no hay notas."
                                      : "Ninguna nota dice eso.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(lista) { nota in
                    Button { enEdicion = nota } label: {
                        FilaDeNota(nota: nota)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indices in
                    indices.map { lista[$0] }.forEach(diario.borrar)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Paleta.fondo)
        .searchable(text: $busqueda, prompt: "Buscar en las notas")
        .navigationTitle("Notas")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { escribiendo = true } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $escribiendo) {
            EditorDeNota(titulo: "Nota nueva", texto: "", importante: false) { texto, importante in
                diario.guardarNota(texto: texto, importante: importante)
            }
        }
        .sheet(item: $enEdicion) { nota in
            EditorDeNota(titulo: "Nota", texto: nota.texto, importante: nota.importante) { texto, importante in
                diario.reemplazar(nota, texto: texto, importante: importante)
            }
        }
    }
}

struct FilaDeNota: View {
    let nota: Nota

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if nota.importante {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Paleta.acento)
                    .padding(.top, 4)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(nota.titulo)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                if !nota.resto.isEmpty {
                    Text(nota.resto)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Text(nota.instante.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct EditorDeNota: View {
    let titulo: String
    @State var texto: String
    @State var importante: Bool
    let guardar: (String, Bool) -> Void

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextEditor(text: $texto)
                    .scrollContentBackground(.hidden)
                    .background(Paleta.fondo)
                    .padding(.horizontal, 12)
                Divider()
                Toggle("Importante", isOn: $importante)
                    .tint(Paleta.acento)
                    .padding()
            }
            .background(Paleta.fondo)
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guardar(texto, importante)
                        cerrar()
                    }
                    .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
