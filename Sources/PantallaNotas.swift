import SwiftUI

/// Notas sueltas con fecha. Las importantes van arriba.
struct PantallaNotas: View {
    @ObservedObject var diario: Diario

    @State private var escribiendo = false
    @State private var enEdicion: Nota?
    @State private var busqueda = ""

    private var lista: [Nota] { diario.notasQueCoinciden(con: busqueda) }

    var body: some View {
        Pantalla {
            Bloque(pie: lista.isEmpty ? nil : "Tocá una nota para editarla. "
                      + "Mantené apretado para borrarla.") {
                if lista.isEmpty {
                    Vacio(busqueda.isEmpty ? "Todavía no hay notas."
                                           : "Ninguna nota dice eso.")
                } else {
                    ForEach(enumerar(lista)) { fila in
                        if fila.puesto > 0 { Linea() }
                        Button { enEdicion = fila.valor } label: {
                            FilaDeNota(nota: fila.valor)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                diario.borrar(fila.valor)
                            } label: {
                                Label("Borrar la nota", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !diario.notas.isEmpty {
                Bloque(titulo: "En total") {
                    Fila("Notas", "\(diario.notas.count)")
                    Linea()
                    Fila("Marcadas", "\(diario.notas.filter(\.importante).count)")
                }
            }
        }
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
                Text(nota.instante.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(Paleta.suave.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

struct EditorDeNota: View {
    let titulo: String
    @State var texto: String
    @State var importante: Bool
    let guardar: (String, Bool) -> Void

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

                    Rectangle()
                        .fill(Paleta.borde)
                        .frame(height: 1)

                    Toggle("Importante", isOn: $importante)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Paleta.texto)
                        .tint(Paleta.acento)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
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
                        guardar(texto, importante)
                        cerrar()
                    }
                    .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
