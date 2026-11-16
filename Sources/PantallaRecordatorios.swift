import SwiftUI

/// Los recordatorios por horario, y el permiso de notificaciones.
struct PantallaRecordatorios: View {
    @ObservedObject private var avisos = Avisos.compartido

    @State private var editando: Recordatorio?
    @State private var creando = false

    var body: some View {
        Pantalla(titulo: "Recordatorios",
                 bajada: "El de proteína se puede anotar desde el aviso mismo") {
            Bloque(titulo: "Permiso",
                   pie: permisoOK ? nil
                      : "Sin permiso, los recordatorios no suenan. Si lo rechazaste "
                      + "antes, se cambia desde Configuración del iPad → Yelin App → "
                      + "Notificaciones.") {
                Fila("Notificaciones", avisos.permiso, resaltado: permisoOK)
                if !permisoOK {
                    Linea()
                    Accion(texto: "Dar permiso", simbolo: "bell") {
                        avisos.pedirPermiso()
                    }
                }
            }

            if avisos.lista.isEmpty {
                Bloque(titulo: "Para empezar rápido") {
                    Accion(texto: "Proteína, 10:00, de lunes a viernes",
                           simbolo: "cup.and.saucer") {
                        avisos.agregar(Recordatorio.nuevo(tipo: .proteina, hora: 10))
                    }
                    Linea()
                    Accion(texto: "Pesarte, 08:00, todos los días",
                           simbolo: "scalemass") {
                        var r = Recordatorio.nuevo(tipo: .pesarse, hora: 8)
                        r.dias = [1, 2, 3, 4, 5, 6, 7]
                        avisos.agregar(r)
                    }
                    Linea()
                    Accion(texto: "Entrenar, 19:00, de lunes a viernes",
                           simbolo: "figure.rower") {
                        avisos.agregar(Recordatorio.nuevo(tipo: .entrenar, hora: 19))
                    }
                }
            } else {
                Bloque(titulo: "Los tuyos",
                       pie: "Tocá uno para cambiarlo. Mantené apretado para borrarlo.") {
                    ForEach(enumerar(avisos.lista)) { fila in
                        if fila.puesto > 0 { Linea() }
                        FilaDeRecordatorio(recordatorio: fila.valor,
                                           alTocar: { editando = fila.valor },
                                           alAlternar: { avisos.alternar(fila.valor) })
                            .contextMenu {
                                Button(role: .destructive) {
                                    avisos.borrar(fila.valor)
                                } label: {
                                    Label("Borrar el recordatorio", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            Boton(texto: "Agregar un recordatorio") { creando = true }

            Bloque(titulo: "Cómo funciona") {
                Celda {
                    VStack(alignment: .leading, spacing: 8) {
                        Explicacion("El de **proteína** trae dos botones en la "
                                    + "notificación: 1 scoop y ½. Se anota sin abrir la app.")
                        Explicacion("Todos tienen **En 30 minutos** para posponerlo "
                                    + "una vez.")
                        Explicacion("Se repiten cada semana en los días elegidos.")
                    }
                }
            }
        }
        .sheet(isPresented: $creando) {
            EditorDeRecordatorio(recordatorio: Recordatorio.nuevo()) { nuevo in
                avisos.agregar(nuevo)
            }
        }
        .sheet(item: $editando) { r in
            EditorDeRecordatorio(recordatorio: r) { cambiado in
                avisos.reemplazar(cambiado)
            }
        }
        .onAppear { avisos.revisarPermiso() }
    }

    private var permisoOK: Bool { avisos.permiso == "Activado" }
}

private struct Explicacion: View {
    let texto: String

    init(_ texto: String) { self.texto = texto }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(Paleta.acento)
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(LocalizedStringKey(texto))
                .font(.system(size: 13))
                .foregroundColor(Paleta.suave)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FilaDeRecordatorio: View {
    let recordatorio: Recordatorio
    let alTocar: () -> Void
    let alAlternar: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: alTocar) {
                HStack(spacing: 14) {
                    Text(recordatorio.horaTexto)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(recordatorio.activo ? Paleta.texto : Paleta.suave)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: recordatorio.tipo.simbolo)
                                .font(.system(size: 11))
                                .foregroundColor(recordatorio.activo ? Paleta.acento : Paleta.suave)
                            Text(recordatorio.titulo)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(recordatorio.activo ? Paleta.texto : Paleta.suave)
                                .lineLimit(1)
                        }
                        Text(recordatorio.diasTexto)
                            .font(.system(size: 12))
                            .foregroundColor(Paleta.suave)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(get: { recordatorio.activo },
                                     set: { _ in alAlternar() }))
                .labelsHidden()
                .tint(Paleta.acento)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Editor

struct EditorDeRecordatorio: View {
    @State var recordatorio: Recordatorio
    let guardar: (Recordatorio) -> Void

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        Hoja(titulo: "Recordatorio", bajada: resumen,
             confirmar: "Guardar",
             puedeConfirmar: !recordatorio.dias.isEmpty,
             alConfirmar: { guardar(recordatorio) }) {
            Bloque(titulo: "De qué") {
                    ForEach(enumerar(Recordatorio.Tipo.allCases)) { fila in
                        if fila.puesto > 0 { Linea() }
                        Button { recordatorio.tipo = fila.valor } label: {
                            HStack(spacing: 11) {
                                Image(systemName: fila.valor.simbolo)
                                    .font(.system(size: 14))
                                    .foregroundColor(Paleta.acento)
                                    .frame(width: 18)
                                Text(fila.valor.nombre)
                                    .font(.system(size: 15))
                                    .foregroundColor(Paleta.texto)
                                Spacer()
                                if recordatorio.tipo == fila.valor {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Paleta.acento)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Bloque(titulo: "A qué hora") {
                    Reloj(hora: $recordatorio.hora, minuto: $recordatorio.minuto)
                }

                Bloque(titulo: "Qué días") {
                    Celda {
                        VStack(spacing: 14) {
                            HStack(spacing: 8) {
                                ForEach(Recordatorio.ordenDeDias, id: \.self) { dia in
                                    BotonDeDia(
                                        inicial: Fechas.inicialDelDia(dia),
                                        elegido: recordatorio.dias.contains(dia)) {
                                            if recordatorio.dias.contains(dia) {
                                                recordatorio.dias.remove(dia)
                                            } else {
                                                recordatorio.dias.insert(dia)
                                            }
                                        }
                                }
                            }
                            HStack(spacing: 8) {
                                Atajo(texto: "Todos") { recordatorio.dias = [1,2,3,4,5,6,7] }
                                Atajo(texto: "L a V") { recordatorio.dias = [2,3,4,5,6] }
                                Atajo(texto: "Finde") { recordatorio.dias = [1,7] }
                            }
                        }
                    }
                }

                Bloque(titulo: recordatorio.tipo == .libre ? "Qué decir" : "Texto propio",
                       pie: recordatorio.tipo == .libre ? nil
                          : "Si lo dejás vacío usa el texto que viene puesto.") {
                    TextField(recordatorio.tipo == .libre ? "Tomar la vitamina"
                                                          : recordatorio.tipo.cuerpoPorDefecto,
                              text: $recordatorio.texto)
                        .font(.system(size: 15))
                        .foregroundColor(Paleta.texto)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }

        }
    }

    private var resumen: String {
        recordatorio.dias.isEmpty ? "Elegí al menos un día"
                                  : recordatorio.horaTexto + " · " + recordatorio.diasTexto
    }
}

/// Hora y minutos con botones grandes, en vez del selector del sistema.
private struct Reloj: View {
    @Binding var hora: Int
    @Binding var minuto: Int

    var body: some View {
        HStack(spacing: 10) {
            rueda(valor: String(format: "%02d", hora), rotulo: "hora",
                  menos: { hora = (hora + 23) % 24 },
                  mas: { hora = (hora + 1) % 24 })
            Text(":")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundColor(Paleta.suave)
            rueda(valor: String(format: "%02d", minuto), rotulo: "minutos",
                  menos: { minuto = (minuto + 55) % 60 },
                  mas: { minuto = (minuto + 5) % 60 })
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func rueda(valor: String, rotulo: String,
                       menos: @escaping () -> Void, mas: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: mas) { flecha("chevron.up") }
            Text(valor)
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Paleta.texto)
            Button(action: menos) { flecha("chevron.down") }
            Text(rotulo)
                .font(.system(size: 10))
                .foregroundColor(Paleta.suave)
        }
        .frame(maxWidth: .infinity)
    }

    private func flecha(_ simbolo: String) -> some View {
        Image(systemName: simbolo)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Paleta.acento)
            .frame(width: 56, height: 34)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Paleta.acento.opacity(0.14)))
    }
}

private struct BotonDeDia: View {
    let inicial: String
    let elegido: Bool
    let tocar: () -> Void

    var body: some View {
        Button(action: tocar) {
            Text(inicial)
                .font(.system(size: 14, weight: elegido ? .bold : .regular))
                .foregroundColor(elegido ? .white : Paleta.suave)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Circle().fill(elegido ? Paleta.acento : Paleta.borde))
        }
        .buttonStyle(.plain)
    }
}

private struct Atajo: View {
    let texto: String
    let tocar: () -> Void

    var body: some View {
        Button(action: tocar) {
            Text(texto)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Paleta.suave)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Capsule().stroke(Paleta.borde, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
