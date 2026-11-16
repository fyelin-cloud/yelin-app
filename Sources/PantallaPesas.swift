import SwiftUI

/// Pesas: anotar series rápido y ver con cuánto venía la vez anterior.
///
/// La idea de diseño es que anotar una serie cueste un toque. Por eso cada
/// ejercicio del día tiene un botón que repite la última serie igual, y al
/// abrir el anotador ya viene cargado con lo último que levantó.
struct PantallaPesas: View {
    @ObservedObject var pesas: Pesas

    @State private var anotando = false
    @State private var ejercicioElegido: String?

    var body: some View {
        Pantalla {
            Hero(numero: Kilos.grande(pesas.volumenDeHoy),
                 unidad: "kg de volumen hoy",
                 estado: estado,
                 señal: pesas.seriesDeHoy.isEmpty ? .esperando : .conectado,
                 alPie: alPie)

            Boton(texto: "Anotar una serie") {
                ejercicioElegido = nil
                anotando = true
            }

            if !pesas.ejerciciosDeHoy.isEmpty { hoy }

            if pesas.seriesDeHoy.isEmpty, let ultimo = pesas.dias().first {
                ultimaSesion(ultimo)
            }

            Bloque {
                Navega(texto: "Historial", simbolo: "calendar",
                       detalle: pesas.dias().isEmpty ? nil : "\(pesas.dias().count) días") {
                    HistorialDePesas(pesas: pesas)
                }
                Linea()
                Navega(texto: "Récords", simbolo: "trophy") {
                    RecordsDePesas(pesas: pesas)
                }
                Linea()
                Navega(texto: "Mis ejercicios", simbolo: "list.bullet",
                       detalle: "\(pesas.lista.count)") {
                    MisEjercicios(pesas: pesas)
                }
            }
        }
        .navigationTitle("Pesas")
        .sheet(isPresented: $anotando) {
            NuevaSerie(pesas: pesas, ejercicio: ejercicioElegido)
        }
    }

    private var estado: String {
        let cuantas = pesas.seriesDeHoy.count
        if cuantas == 0 { return "Todavía no entrenaste hoy" }
        let repeticiones = pesas.seriesDeHoy.reduce(0) { $0 + $1.repeticiones }
        return "\(cuantas) series · \(repeticiones) repeticiones"
    }

    private var alPie: String? {
        guard !pesas.ejerciciosDeHoy.isEmpty else { return nil }
        return pesas.ejerciciosDeHoy.joined(separator: " · ")
    }

    // MARK: Lo de hoy, ejercicio por ejercicio

    private var hoy: some View {
        Bloque(titulo: "Hoy", pie: "Tocá el más para repetir la última serie igual.") {
            ForEach(enumerar(pesas.ejerciciosDeHoy)) { fila in
                if fila.puesto > 0 { Linea() }
                EjercicioDeHoy(pesas: pesas, ejercicio: fila.valor) {
                    ejercicioElegido = fila.valor
                    anotando = true
                }
            }
        }
    }

    private func ultimaSesion(_ dia: DiaDePesas) -> some View {
        Bloque(titulo: "La última vez") {
            Celda {
                VStack(alignment: .leading, spacing: 5) {
                    Text(Fechas.relativa(dia.dia))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Paleta.texto)
                    Text(dia.ejercicios.joined(separator: " · "))
                        .font(.system(size: 13))
                        .foregroundColor(Paleta.suave)
                    Text("\(Kilos.grande(dia.volumen)) kg de volumen · \(dia.series.count) series")
                        .font(.system(size: 12))
                        .foregroundColor(Paleta.suave)
                }
            }
        }
    }
}

/// Un ejercicio del día: las series que hizo y el botón para repetir.
private struct EjercicioDeHoy: View {
    @ObservedObject var pesas: Pesas
    let ejercicio: String
    let anotarOtra: () -> Void

    var body: some View {
        let series = pesas.seriesDeHoy(de: ejercicio)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(ejercicio)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Paleta.texto)

                HStack(spacing: 6) {
                    ForEach(series) { serie in
                        Text(serie.resumen)
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(Paleta.texto.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Paleta.acento.opacity(0.16)))
                            .contextMenu {
                                Button(role: .destructive) {
                                    pesas.borrar(serie)
                                } label: {
                                    Label("Borrar esta serie", systemImage: "trash")
                                }
                            }
                    }
                }

                if let antes = pesas.ultimaVez(de: ejercicio) {
                    Text("La última vez: " + antes.series.map(\.resumen).joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(Paleta.suave)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Button(action: repetir) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Paleta.acento)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Paleta.acento.opacity(0.14)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func repetir() {
        guard let ultima = pesas.sugerencia(para: ejercicio) else {
            anotarOtra()
            return
        }
        pesas.anotar(ejercicio: ejercicio,
                     repeticiones: ultima.repeticiones,
                     kilos: ultima.kilos)
    }
}

// MARK: - Anotar una serie

struct NuevaSerie: View {
    @ObservedObject var pesas: Pesas
    var ejercicio: String?

    @State private var elegido = ""
    @State private var repeticiones = 10
    @State private var kilos: Double = 20
    @State private var cargado = false

    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            Pantalla(titulo: "Serie nueva", bajada: bajada) {
                Bloque(titulo: "Ejercicio") {
                    Menu {
                        ForEach(pesas.lista, id: \.self) { nombre in
                            Button(nombre) { elegir(nombre) }
                        }
                    } label: {
                        HStack {
                            Text(elegido.isEmpty ? "Elegir" : elegido)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(elegido.isEmpty ? Paleta.suave : Paleta.texto)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Paleta.suave)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .contentShape(Rectangle())
                    }
                }

                Bloque(titulo: "Repeticiones") {
                    Contador(valor: Double(repeticiones),
                             texto: "\(repeticiones)",
                             paso: "1",
                             menos: { repeticiones = max(1, repeticiones - 1) },
                             mas: { repeticiones = min(300, repeticiones + 1) })
                }

                Bloque(titulo: "Kilos", pie: "Si es con el peso del cuerpo, dejalo en 0.") {
                    Contador(valor: kilos,
                             texto: Kilos.texto(kilos),
                             paso: "2,5",
                             menos: { kilos = max(0, kilos - 2.5) },
                             mas: { kilos = min(500, kilos + 2.5) })
                }

                if let antes = anterior {
                    Bloque(titulo: "Con cuánto venías") {
                        Celda {
                            Text(antes)
                                .font(.system(size: 14))
                                .foregroundColor(Paleta.suave)
                        }
                    }
                }

                Boton(texto: "Guardar") {
                    pesas.anotar(ejercicio: elegido, repeticiones: repeticiones, kilos: kilos)
                    cerrar()
                }
                .opacity(elegido.isEmpty ? 0.4 : 1)
                .disabled(elegido.isEmpty)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
            .onAppear(perform: preparar)
        }
    }

    private var bajada: String {
        elegido.isEmpty ? "Elegí el ejercicio" : "Volumen: \(Kilos.grande(Double(repeticiones) * kilos)) kg"
    }

    private var anterior: String? {
        guard !elegido.isEmpty, let dia = pesas.ultimaVez(de: elegido) else { return nil }
        return Fechas.relativa(dia.dia).capitalizedPrimera + ": "
            + dia.series.map(\.resumen).joined(separator: ", ")
    }

    private func preparar() {
        guard !cargado else { return }
        cargado = true
        if let ejercicio {
            elegir(ejercicio)
        } else if let primero = pesas.lista.first {
            elegir(primero)
        }
    }

    /// Al elegir un ejercicio se precargan las repeticiones y los kilos de la
    /// última serie que hizo. Nueve de cada diez veces es exactamente eso.
    private func elegir(_ nombre: String) {
        elegido = nombre
        if let ultima = pesas.sugerencia(para: nombre) {
            repeticiones = ultima.repeticiones
            kilos = ultima.kilos
        }
    }
}

/// Menos, número grande y más. Reemplaza al `Stepper` de iOS, que es chiquito
/// y gris.
struct Contador: View {
    let valor: Double
    let texto: String
    let paso: String
    let menos: () -> Void
    let mas: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            boton("minus", accion: menos)
            VStack(spacing: 1) {
                Text(texto)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Paleta.texto)
                Text("de " + paso + " en " + paso)
                    .font(.system(size: 10))
                    .foregroundColor(Paleta.suave)
            }
            .frame(maxWidth: .infinity)
            boton("plus", accion: mas)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }

    private func boton(_ simbolo: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Image(systemName: simbolo)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Paleta.acento)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Paleta.acento.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Historial

struct HistorialDePesas: View {
    @ObservedObject var pesas: Pesas

    var body: some View {
        Pantalla {
            let dias = pesas.dias()
            if dias.isEmpty {
                Bloque { Vacio("Todavía no anotaste ninguna serie.") }
            } else {
                Bloque(titulo: "Resumen") {
                    Fila("Días entrenados", "\(dias.count)")
                    Linea()
                    Fila("Series en total", "\(pesas.series.count)")
                    Linea()
                    Fila("Volumen acumulado",
                         Kilos.grande(dias.reduce(0) { $0 + $1.volumen }) + " kg")
                    Linea()
                    Fila("Mejor día", mejorDia(dias))
                }

                Bloque(titulo: "Día por día",
                       pie: "Mantené apretado un día para borrar sus series.") {
                    ForEach(enumerar(dias)) { fila in
                        if fila.puesto > 0 { Linea() }
                        DiaDeHistorial(dia: fila.valor, pesas: pesas)
                    }
                }
            }
        }
        .navigationTitle("Historial")
    }

    private func mejorDia(_ dias: [DiaDePesas]) -> String {
        guard let mejor = dias.max(by: { $0.volumen < $1.volumen }) else { return "—" }
        return Kilos.grande(mejor.volumen) + " kg · " + Fechas.corta(mejor.dia)
    }
}

private struct DiaDeHistorial: View {
    let dia: DiaDePesas
    @ObservedObject var pesas: Pesas

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(Fechas.relativa(dia.dia).capitalizedPrimera)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Paleta.texto)
                Spacer()
                Text(Kilos.grande(dia.volumen) + " kg")
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(Paleta.acento)
            }
            ForEach(dia.ejercicios, id: \.self) { ejercicio in
                let series = dia.series.filter { $0.ejercicio == ejercicio }
                Text(ejercicio + " — " + series.map(\.resumen).joined(separator: ", "))
                    .font(.system(size: 12))
                    .foregroundColor(Paleta.suave)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                dia.series.forEach(pesas.borrar)
            } label: {
                Label("Borrar el día entero", systemImage: "trash")
            }
        }
    }
}

// MARK: - Récords

struct RecordsDePesas: View {
    @ObservedObject var pesas: Pesas

    var body: some View {
        Pantalla(bajada: "El kilaje más alto que levantaste en cada ejercicio.") {
            let conHistorial = pesas.ejerciciosConHistorial()
            if conHistorial.isEmpty {
                Bloque { Vacio("Todavía no hay nada anotado.") }
            } else {
                Bloque {
                    ForEach(enumerar(conHistorial)) { fila in
                        if fila.puesto > 0 { Linea() }
                        if let record = pesas.record(de: fila.valor) {
                            Celda {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(fila.valor)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(Paleta.texto)
                                        Text(Fechas.corta(record.instante))
                                            .font(.system(size: 11))
                                            .foregroundColor(Paleta.suave)
                                    }
                                    Spacer()
                                    Text(record.resumen)
                                        .font(.system(size: 15, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundColor(Paleta.acento)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Récords")
    }
}

// MARK: - La lista de ejercicios

struct MisEjercicios: View {
    @ObservedObject var pesas: Pesas
    @State private var nuevo = ""

    var body: some View {
        Pantalla(bajada: "Los que aparecen al anotar una serie.") {
            Bloque(titulo: "Agregar") {
                HStack(spacing: 10) {
                    TextField("Nombre del ejercicio", text: $nuevo)
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
                    .opacity(nuevo.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Bloque(titulo: "La lista",
                   pie: "Mantené apretado para sacar uno. Lo que ya anotaste no se borra; "
                      + "solo deja de ofrecerse. También se puede editar el archivo "
                      + "ejercicios.txt desde Archivos.") {
                if pesas.lista.isEmpty {
                    Vacio("No quedó ninguno. Agregá al menos uno para poder anotar.")
                } else {
                    ForEach(enumerar(pesas.lista)) { fila in
                        if fila.puesto > 0 { Linea() }
                        Celda {
                            HStack {
                                Text(fila.valor)
                                    .font(.system(size: 15))
                                    .foregroundColor(Paleta.texto)
                                Spacer()
                                if let record = pesas.record(de: fila.valor) {
                                    Text(record.resumen)
                                        .font(.system(size: 12))
                                        .monospacedDigit()
                                        .foregroundColor(Paleta.suave)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button(role: .destructive) {
                                pesas.quitarEjercicio(fila.valor)
                            } label: {
                                Label("Sacar de la lista", systemImage: "minus.circle")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Mis ejercicios")
    }

    private func agregar() {
        pesas.agregarEjercicio(nuevo)
        nuevo = ""
    }
}
