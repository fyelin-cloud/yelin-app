import Foundation

/// Arma una página web con todo lo que guardó la app y la deja en Drive.
///
/// **Para qué**: los CSV y el `resumen.md` sirven para procesar, pero no para
/// mirar. Esto es para abrir con doble clic desde la computadora y ver cómo
/// viene todo sin tocar el iPad.
///
/// Es **un solo archivo y no pide nada por internet**: los gráficos están
/// dibujados en SVG dentro del mismo HTML y los estilos van incrustados. Se
/// abre sin conexión, desde Drive o desde el disco.
enum Panel {

    static func generar(almacen: Almacen) -> String {
        let pesadas = almacen.cargarPesadas()
        let sesiones = almacen.cargarSesiones()
        let series = almacen.cargarSeries()
        let consumo = almacen.cargarConsumo()
        let gastos = almacen.cargarGastos()
        let notas = almacen.cargarNotas()

        let puntos = Analisis.porDia(pesadas)
        let promedio = Analisis.promedioMovil(puntos)
        let semana = Semana.armar(pesadas: pesadas, sesiones: sesiones, consumo: consumo,
                                  gastos: gastos, series: series)
        let constancia = Constancia.armar(pesadas: pesadas, sesiones: sesiones, series: series)

        var h = ""
        h += cabecera()
        h += encabezado()
        h += tiras(puntos: puntos, promedio: promedio, semana: semana, constancia: constancia)
        h += bloqueDePeso(puntos: puntos, promedio: promedio, pesadas: pesadas)
        h += bloqueDeSemana(semana)
        h += bloqueDeConstancia(constancia)
        h += bloqueDeRemo(sesiones)
        h += bloqueDePesas(series)
        h += bloqueDeGastos(gastos)
        h += bloqueDeProteina(consumo)
        h += bloqueDeNotas(notas)
        h += pie()
        return h
    }

    // MARK: - Estilos

    private static func cabecera() -> String {
        """
        <!doctype html>
        <html lang="es">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Yelin App — panel</title>
        <style>
        :root{
          --fondo:#0E0F10; --superficie:#17191B; --borde:#24282B;
          --texto:#ECEAE6; --suave:#8C8F93; --acento:#1C7BD9;
          --bien:#42C778; --mal:#DB6B61;
        }
        *{box-sizing:border-box}
        body{
          margin:0; background:var(--fondo); color:var(--texto);
          font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Inter,Roboto,Arial,sans-serif;
          font-size:15px; line-height:1.5;
          padding:28px 20px 60px;
        }
        .hoja{max-width:1000px;margin:0 auto}
        header{display:flex;align-items:baseline;gap:14px;margin-bottom:26px}
        .logo{
          font-size:38px;font-weight:800;font-style:italic;letter-spacing:-.06em;
          background:linear-gradient(90deg,#1C7BD9,rgba(28,123,217,.3));
          -webkit-background-clip:text;background-clip:text;color:transparent;
        }
        h1{font-size:26px;margin:0;font-weight:700}
        .sello{color:var(--suave);font-size:13px;margin-left:auto}
        section{
          background:var(--superficie);border:1px solid var(--borde);border-radius:18px;
          padding:20px 22px;margin-bottom:16px;
        }
        h2{font-size:14px;font-weight:600;margin:0 0 16px;color:rgba(236,234,230,.78)}
        .tiras{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;
               background:none;border:none;padding:0;margin-bottom:16px}
        .tira{background:var(--superficie);border:1px solid var(--borde);border-radius:16px;padding:14px}
        .tira .n{font-size:27px;font-weight:600;letter-spacing:-.02em}
        .tira .r{font-size:13px;color:rgba(236,234,230,.8);margin-top:2px}
        .tira .d{font-size:11px;color:var(--suave);margin-top:2px}
        .bien{color:var(--bien)} .mal{color:var(--mal)} .azul{color:var(--acento)}
        .gris{color:var(--suave)}
        table{width:100%;border-collapse:collapse;font-size:14px}
        th{text-align:left;font-weight:500;color:var(--suave);font-size:12px;padding:0 0 8px}
        th.num,td.num{text-align:right;font-variant-numeric:tabular-nums}
        td{padding:9px 0;border-top:1px solid var(--borde)}
        td.chico{color:var(--suave);font-size:12px}
        .barra{height:5px;background:var(--borde);border-radius:3px;overflow:hidden;margin-top:6px}
        .barra i{display:block;height:100%;background:var(--acento);border-radius:3px}
        .vacio{color:var(--suave);font-size:14px}
        .periodos{margin-bottom:18px}
        .periodos input{position:absolute;opacity:0;pointer-events:none}
        .periodos label{
          display:inline-block;font-size:12px;color:var(--suave);cursor:pointer;
          padding:5px 12px;border:1px solid var(--borde);border-radius:999px;margin:0 6px 14px 0;
        }
        .g{display:none}
        #p30:checked~label[for=p30],#p90:checked~label[for=p90],#pt:checked~label[for=pt]
          {color:var(--texto);border-color:var(--acento);background:rgba(28,123,217,.16)}
        #p30:checked~.g30,#p90:checked~.g90,#pt:checked~.gt{display:block}
        svg{display:block;width:100%;height:auto}
        .malla{display:grid;grid-auto-flow:column;grid-template-rows:repeat(7,14px);
               grid-auto-columns:14px;gap:3px;justify-content:start;overflow-x:auto}
        .malla div{width:14px;height:14px;border-radius:3px}
        .ref{display:flex;gap:16px;margin-top:14px;font-size:11px;color:var(--suave);align-items:center;flex-wrap:wrap}
        .ref span{display:flex;gap:6px;align-items:center}
        .ref i{width:10px;height:10px;border-radius:3px;display:block}
        .semanal{display:flex;align-items:flex-end;gap:10px;height:150px;margin-top:4px}
        .semanal div{flex:1;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;height:100%}
        .semanal b{display:block;width:100%;background:linear-gradient(180deg,var(--acento),rgba(28,123,217,.4));border-radius:5px}
        .semanal em{font-style:normal;font-size:10px;color:var(--suave);margin-bottom:4px}
        .semanal u{text-decoration:none;font-size:11px;color:var(--suave);margin-top:6px}
        footer{color:var(--suave);font-size:12px;margin-top:26px;line-height:1.7}
        footer code{color:rgba(236,234,230,.8)}
        @media print{body{background:#fff;color:#000}section{break-inside:avoid}}
        </style>
        </head>
        <body><div class="hoja">
        """
    }

    private static func encabezado() -> String {
        """
        <header>
          <span class="logo">Y5</span>
          <h1>Panel</h1>
          <span class="sello">Actualizado el \(fechaYHora(Date()))</span>
        </header>
        """
    }

    // MARK: - Las tiras de arriba

    private static func tiras(puntos: [PuntoDePeso], promedio: [PuntoDePeso],
                              semana: Semana, constancia: Constancia) -> String {
        var t = "<div class=\"tiras\">"

        if let ultimo = puntos.last {
            let cambio = Analisis.cambio(puntos, dias: 7)
            t += tira(numero: coma(ultimo.kg, 2),
                      rotulo: "Peso, kg",
                      detalle: cambio.map { String(format: "%+.2f kg en 7 días", $0) }
                               ?? "Sin historial para comparar",
                      clase: cambio.map { $0 < 0 ? "bien" : ($0 > 0 ? "mal" : "") } ?? "")
        } else {
            t += tira(numero: "—", rotulo: "Peso", detalle: "Sin pesadas", clase: "gris")
        }

        if let media = promedio.last {
            t += tira(numero: coma(media.kg, 2), rotulo: "Promedio de 7 días",
                      detalle: tendencia(puntos), clase: "")
        }

        t += tira(numero: semana.metros.ahora > 0 ? miles(semana.metros.ahora) : "—",
                  rotulo: "Metros esta semana",
                  detalle: comparado(semana.metros, unidad: " m"),
                  clase: semana.metros.ahora > 0 ? "" : "gris")

        t += tira(numero: semana.volumenDePesas.ahora > 0 ? miles(semana.volumenDePesas.ahora) : "—",
                  rotulo: "Volumen de pesas, kg",
                  detalle: Int(semana.diasDePesas.ahora) == 1 ? "1 día esta semana"
                         : "\(Int(semana.diasDePesas.ahora)) días esta semana",
                  clase: semana.volumenDePesas.ahora > 0 ? "" : "gris")

        t += tira(numero: "\(semana.diasActivos)/7", rotulo: "Días con entrenamiento",
                  detalle: "Remo o pesas",
                  clase: semana.diasActivos > 0 ? "azul" : "gris")

        t += tira(numero: "\(constancia.rachaActual)", rotulo: "Racha de días",
                  detalle: "La más larga: \(constancia.rachaMasLarga)",
                  clase: constancia.rachaActual > 0 ? "azul" : "gris")

        return t + "</div>"
    }

    private static func tira(numero: String, rotulo: String,
                             detalle: String, clase: String) -> String {
        """
        <div class="tira"><div class="n \(clase)">\(numero)</div>\
        <div class="r">\(esc(rotulo))</div><div class="d">\(esc(detalle))</div></div>
        """
    }

    // MARK: - Peso

    private static func bloqueDePeso(puntos: [PuntoDePeso], promedio: [PuntoDePeso],
                                     pesadas: [Pesada]) -> String {
        guard puntos.count >= 2 else {
            return "<section><h2>Peso</h2><p class=\"vacio\">Hacen falta al menos dos días con pesada para dibujar la tendencia.</p></section>"
        }
        func recorte(_ dias: Int?) -> ([PuntoDePeso], [PuntoDePeso]) {
            guard let dias, let ultimo = puntos.last else { return (puntos, promedio) }
            let desde = ultimo.fecha.addingTimeInterval(-Double(dias) * 86_400)
            return (puntos.filter { $0.fecha >= desde }, promedio.filter { $0.fecha >= desde })
        }
        let (p30, m30) = recorte(30)
        let (p90, m90) = recorte(90)

        return """
        <section><h2>Peso</h2>
        <div class="periodos">
          <input type="radio" name="per" id="p30" checked>
          <input type="radio" name="per" id="p90">
          <input type="radio" name="per" id="pt">
          <label for="p30">30 días</label><label for="p90">90 días</label><label for="pt">Todo</label>
          <div class="g g30">\(curva(p30, m30))</div>
          <div class="g g90">\(curva(p90, m90))</div>
          <div class="g gt">\(curva(puntos, promedio))</div>
        </div>
        <table><tr><th>Dato</th><th class="num">Valor</th></tr>
        \(filaHTML("Último", coma(puntos.last?.kg ?? 0, 2) + " kg"))
        \(filaHTML("Promedio de 7 días", promedio.last.map { coma($0.kg, 2) + " kg" } ?? "—"))
        \(filaHTML("Cambio en 7 días", conSigno(Analisis.cambio(puntos, dias: 7))))
        \(filaHTML("Cambio en 30 días", conSigno(Analisis.cambio(puntos, dias: 30))))
        \(filaHTML("Tendencia", tendencia(puntos)))
        \(filaHTML("Días con registro", "\(puntos.count)"))
        \(filaHTML("Pesadas en total", "\(pesadas.count)"))
        </table></section>
        """
    }

    /// El gráfico de peso: los puntos de cada día y la línea del promedio.
    private static func curva(_ puntos: [PuntoDePeso], _ promedio: [PuntoDePeso]) -> String {
        let ancho = 920.0, alto = 290.0
        let izq = 46.0, der = 14.0, arriba = 14.0, abajo = 28.0
        guard puntos.count >= 2,
              let primera = puntos.first?.fecha.timeIntervalSince1970,
              let ultima = puntos.last?.fecha.timeIntervalSince1970,
              ultima > primera else { return "" }

        let rango = Analisis.rangoVertical(puntos)
        let minimo = rango.lowerBound, maximo = rango.upperBound
        let altura = max(maximo - minimo, 0.1)

        func x(_ f: Date) -> Double {
            izq + (f.timeIntervalSince1970 - primera) / (ultima - primera) * (ancho - izq - der)
        }
        func y(_ kg: Double) -> Double {
            arriba + (1 - (kg - minimo) / altura) * (alto - arriba - abajo)
        }

        // Sin preserveAspectRatio="none": si no, los números del eje se estiran.
        var s = "<svg viewBox=\"0 0 \(fmt(ancho)) \(fmt(alto))\" "
        s += "xmlns=\"http://www.w3.org/2000/svg\">"

        // Rayas horizontales con su número
        for paso in 0...4 {
            let kg = minimo + altura * Double(paso) / 4
            let yy = y(kg)
            s += "<line x1=\"\(fmt(izq))\" y1=\"\(fmt(yy))\" x2=\"\(fmt(ancho - der))\" y2=\"\(fmt(yy))\" stroke=\"#24282B\" stroke-width=\"1\"/>"
            s += "<text x=\"\(fmt(izq - 8))\" y=\"\(fmt(yy + 4))\" fill=\"#8C8F93\" font-size=\"11\" text-anchor=\"end\">\(coma(kg, 1))</text>"
        }

        // Fechas abajo: la primera, la del medio y la última
        for (fecha, ancla) in [(puntos[0].fecha, "start"),
                               (puntos[puntos.count / 2].fecha, "middle"),
                               (puntos[puntos.count - 1].fecha, "end")] {
            s += "<text x=\"\(fmt(x(fecha)))\" y=\"\(fmt(alto - 8))\" fill=\"#8C8F93\" font-size=\"11\" text-anchor=\"\(ancla)\">\(diaYMes(fecha))</text>"
        }

        // La línea del promedio
        if promedio.count >= 2 {
            let camino = promedio.map { "\(fmt(x($0.fecha))),\(fmt(y($0.kg)))" }.joined(separator: " ")
            s += "<polyline points=\"\(camino)\" fill=\"none\" stroke=\"#1C7BD9\" stroke-width=\"2.5\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>"
        }

        // Cada día
        for p in puntos {
            s += "<circle cx=\"\(fmt(x(p.fecha)))\" cy=\"\(fmt(y(p.kg)))\" r=\"2.6\" fill=\"#8C8F93\"><title>\(diaYMes(p.fecha)): \(coma(p.kg, 2)) kg</title></circle>"
        }

        return s + "</svg>"
    }

    // MARK: - La semana

    private static func bloqueDeSemana(_ s: Semana) -> String {
        var h = "<section><h2>La semana — del \(diaYMes(s.desde)) al \(diaYMes(s.hasta))</h2>"

        h += "<div class=\"semanal\">"
        let techo = max(s.metrosPorDia.map { $0.metros }.max() ?? 0, 1)
        for dia in s.metrosPorDia {
            let altura = dia.metros > 0 ? max(8, dia.metros / techo * 104) : 3
            let fondo = dia.metros > 0 ? "" : "background:#24282B;"
            h += "<div><em>\(dia.metros > 0 ? "\(Int(dia.metros))" : "")</em>"
            h += "<b style=\"\(fondo)height:\(fmt(altura))px\"></b>"
            h += "<u>\(inicial(dia.dia))\(dia.huboPesas ? " ·" : "")</u></div>"
        }
        h += "</div>"

        h += "<table style=\"margin-top:18px\"><tr><th>Contra la semana anterior</th><th class=\"num\">Diferencia</th></tr>"
        h += filaHTML("Peso promedio", conSigno(s.pesoPromedio.hayConQueComparar ? s.pesoPromedio.cambio : nil))
        h += filaHTML("Metros remados", String(format: "%+.0f m", s.metros.cambio))
        h += filaHTML("Minutos remando", String(format: "%+.0f min", s.minutosRemando.cambio))
        h += filaHTML("Días de pesas", String(format: "%+.0f", s.diasDePesas.cambio))
        h += filaHTML("Volumen de pesas", String(format: "%+.0f kg", s.volumenDePesas.cambio))
        h += filaHTML("Scoops", String(format: "%+.1f", s.scoops.cambio))
        h += filaHTML("Gastos", (s.gastos.cambio >= 0 ? "+$" : "−$") + miles(abs(s.gastos.cambio)))
        h += "</table>"

        if !s.observaciones.isEmpty {
            h += "<table style=\"margin-top:18px\"><tr><th>Lo que se nota</th></tr>"
            for frase in s.observaciones { h += "<tr><td>\(esc(frase))</td></tr>" }
            h += "</table>"
        }
        return h + "</section>"
    }

    // MARK: - Constancia

    private static func bloqueDeConstancia(_ c: Constancia) -> String {
        var h = "<section><h2>Constancia — los últimos tres meses</h2><div class=\"malla\">"
        for semana in c.semanas {
            for dia in semana {
                let color: String
                switch dia.nivel {
                case 3: color = "#1C7BD9"
                case 2: color = "rgba(28,123,217,.62)"
                case 1: color = "rgba(28,123,217,.22)"
                default: color = "rgba(36,40,43,.75)"
                }
                let opacidad = dia.esFuturo ? ";opacity:.25" : ""
                h += "<div style=\"background:\(color)\(opacidad)\" title=\"\(diaYMes(dia.dia))\"></div>"
            }
        }
        h += "</div><div class=\"ref\">"
        h += "<span><i style=\"background:rgba(28,123,217,.22)\"></i>Te pesaste</span>"
        h += "<span><i style=\"background:rgba(28,123,217,.62)\"></i>Entrenaste</span>"
        h += "<span><i style=\"background:#1C7BD9\"></i>Remo y pesas</span>"
        h += "</div>"
        h += "<table style=\"margin-top:18px\"><tr><th>Racha</th><th class=\"num\">Días</th></tr>"
        h += filaHTML("Seguidos entrenando", "\(c.rachaActual)")
        h += filaHTML("La más larga", "\(c.rachaMasLarga)")
        h += filaHTML("Entrenados en los últimos 30", "\(c.entrenadosEnTreinta) de 30")
        h += filaHTML("Días entrenados en total", "\(c.totalEntrenados)")
        h += filaHTML("Días que te pesaste", "\(c.diasConPesada)")
        return h + "</table></section>"
    }

    // MARK: - Remo

    private static func bloqueDeRemo(_ sesiones: [SesionDeRemo]) -> String {
        guard !sesiones.isEmpty else {
            return "<section><h2>Remo</h2><p class=\"vacio\">Todavía no hay sesiones guardadas.</p></section>"
        }
        let orden = sesiones.sorted { $0.inicio > $1.inicio }
        let metros = sesiones.reduce(0.0) { $0 + $1.metros }
        let segundos = sesiones.reduce(0.0) { $0 + $1.segundosRemando }

        var h = "<section><h2>Remo — \(sesiones.count) sesiones, \(miles(metros)) m, \(enHoras(segundos)) remando</h2>"
        h += "<table><tr><th>Fecha</th><th class=\"num\">Metros</th><th class=\"num\">Remando</th>"
        h += "<th class=\"num\">Ritmo /500</th><th class=\"num\">Watts</th><th class=\"num\">Paladas</th></tr>"
        for s in orden.prefix(25) {
            h += "<tr><td>\(fechaYHora(s.inicio))</td>"
            h += "<td class=\"num\">\(fmt(s.metros))</td>"
            h += "<td class=\"num\">\(enMinutos(s.segundosRemando))</td>"
            h += "<td class=\"num\">\(s.ritmoPromedio > 0 ? enMinutos(s.ritmoPromedio) : "—")</td>"
            h += "<td class=\"num\">\(fmt(s.wattsPromedio))</td>"
            h += "<td class=\"num\">\(s.paladas)</td></tr>"
        }
        h += "</table>"
        h += "<p class=\"vacio\" style=\"margin-bottom:0\">La distancia y el ritmo los calcula la app: la máquina no los manda. Falta calibrarlos contra el display.</p>"
        return h + "</section>"
    }

    // MARK: - Pesas

    private static func bloqueDePesas(_ series: [Serie]) -> String {
        guard !series.isEmpty else {
            return "<section><h2>Pesas</h2><p class=\"vacio\">Todavía no hay series anotadas.</p></section>"
        }
        let calendario = Calendar.current
        var porDia: [Date: [Serie]] = [:]
        for s in series { porDia[calendario.startOfDay(for: s.instante), default: []].append(s) }
        let dias = porDia.keys.sorted(by: >)
        let volumen = series.reduce(0.0) { $0 + $1.volumen }

        var h = "<section><h2>Pesas — \(dias.count) días, \(miles(volumen)) kg de volumen</h2>"
        h += "<table><tr><th>Día</th><th>Qué hizo</th><th class=\"num\">Volumen</th></tr>"
        for dia in dias.prefix(14) {
            let delDia = (porDia[dia] ?? []).sorted { $0.instante < $1.instante }
            var nombres: [String] = []
            for s in delDia where !nombres.contains(s.ejercicio) { nombres.append(s.ejercicio) }
            let detalle = nombres.map { nombre -> String in
                let suyas = delDia.filter { $0.ejercicio == nombre }
                return esc(nombre) + " <span class=\"gris\">"
                     + esc(suyas.map { $0.resumen }.joined(separator: ", ")) + "</span>"
            }.joined(separator: "<br>")
            h += "<tr><td>\(diaYMes(dia))</td><td>\(detalle)</td>"
            h += "<td class=\"num\">\(miles(delDia.reduce(0) { $0 + $1.volumen })) kg</td></tr>"
        }
        h += "</table>"

        var ejercicios: [String] = []
        for s in series where !ejercicios.contains(s.ejercicio) { ejercicios.append(s.ejercicio) }
        h += "<table style=\"margin-top:18px\"><tr><th>Récord por ejercicio</th><th class=\"num\">Mejor serie</th><th class=\"num\">Cuándo</th></tr>"
        for nombre in ejercicios.sorted() {
            let suyas = series.filter { $0.ejercicio == nombre }
            if let mejor = suyas.max(by: { $0.kilos < $1.kilos }) {
                h += "<tr><td>\(esc(nombre))</td><td class=\"num\">\(esc(mejor.resumen))</td>"
                h += "<td class=\"num chico\">\(diaYMes(mejor.instante))</td></tr>"
            }
        }
        return h + "</table></section>"
    }

    // MARK: - Gastos

    private static func bloqueDeGastos(_ gastos: [Gasto]) -> String {
        guard !gastos.isEmpty else {
            return "<section><h2>Gastos</h2><p class=\"vacio\">Todavía no hay gastos anotados.</p></section>"
        }
        let calendario = Calendar.current
        func delMes(_ atras: Int) -> [Gasto] {
            guard let base = calendario.date(byAdding: .month, value: -atras, to: Date()) else { return [] }
            let m = calendario.component(.month, from: base)
            let a = calendario.component(.year, from: base)
            return gastos.filter {
                calendario.component(.month, from: $0.instante) == m
                    && calendario.component(.year, from: $0.instante) == a
            }
        }
        let esteMes = delMes(0), mesPasado = delMes(1)
        let total = esteMes.reduce(0.0) { $0 + $1.monto }
        let antes = mesPasado.reduce(0.0) { $0 + $1.monto }

        var h = "<section><h2>Gastos — $\(miles(total)) este mes"
        if antes > 0 {
            let d = total - antes
            h += " <span class=\"\(d >= 0 ? "mal" : "bien")\">(\(d >= 0 ? "+" : "−")$\(miles(abs(d))) contra el mes pasado)</span>"
        }
        h += "</h2>"

        var porCategoria: [String: Double] = [:]
        for g in esteMes { porCategoria[g.categoria, default: 0] += g.monto }
        let techo = porCategoria.values.max() ?? 1

        h += "<table><tr><th>Categoría</th><th class=\"num\">Este mes</th><th class=\"num\">Mes pasado</th></tr>"
        for (categoria, monto) in porCategoria.sorted(by: { $0.value > $1.value }) {
            let previo = mesPasado.filter { $0.categoria == categoria }.reduce(0.0) { $0 + $1.monto }
            h += "<tr><td>\(esc(categoria))<div class=\"barra\"><i style=\"width:\(fmt(monto / techo * 100))%\"></i></div></td>"
            h += "<td class=\"num\">$\(miles(monto))</td>"
            h += "<td class=\"num chico\">\(previo > 0 ? "$" + miles(previo) : "—")</td></tr>"
        }
        h += "</table>"

        h += "<table style=\"margin-top:18px\"><tr><th>Último</th><th>Detalle</th><th class=\"num\">Monto</th></tr>"
        for g in esteMes.sorted(by: { $0.instante > $1.instante }).prefix(20) {
            h += "<tr><td>\(diaYMes(g.instante)) — \(esc(g.categoria))</td>"
            h += "<td class=\"chico\">\(esc(g.detalle))</td>"
            h += "<td class=\"num\">$\(miles(g.monto))</td></tr>"
        }
        return h + "</table></section>"
    }

    // MARK: - Proteína

    private static func bloqueDeProteina(_ consumo: [Consumo]) -> String {
        guard !consumo.isEmpty else {
            return "<section><h2>Proteína</h2><p class=\"vacio\">Todavía no hay nada anotado.</p></section>"
        }
        let calendario = Calendar.current
        var porDia: [Date: Double] = [:]
        for c in consumo { porDia[calendario.startOfDay(for: c.instante), default: 0] += c.cantidad }
        let dias = porDia.keys.sorted(by: >).prefix(14)
        let techo = porDia.values.max() ?? 1

        var h = "<section><h2>Proteína — últimos días con registro</h2><table>"
        h += "<tr><th>Día</th><th class=\"num\">Scoops</th></tr>"
        for dia in dias {
            let total = porDia[dia] ?? 0
            h += "<tr><td>\(diaYMes(dia))<div class=\"barra\"><i style=\"width:\(fmt(total / techo * 100))%\"></i></div></td>"
            h += "<td class=\"num\">\(coma(total, total == total.rounded() ? 0 : 1))</td></tr>"
        }
        return h + "</table></section>"
    }

    // MARK: - Notas

    private static func bloqueDeNotas(_ notas: [Nota]) -> String {
        guard !notas.isEmpty else { return "" }
        var h = "<section><h2>Notas</h2><table>"
        let importantes = notas.filter(\.importante)
        if !importantes.isEmpty {
            h += "<tr><th>Marcadas como importantes</th><th class=\"num\">Cuándo</th></tr>"
            for n in importantes.prefix(10) {
                h += "<tr><td>\(esc(n.titulo))</td><td class=\"num chico\">\(diaYMes(n.instante))</td></tr>"
            }
        }
        h += "<tr><th style=\"padding-top:18px\">Últimas</th><th class=\"num\" style=\"padding-top:18px\">Cuándo</th></tr>"
        for n in notas.sorted(by: { $0.instante > $1.instante }).prefix(10) {
            h += "<tr><td>\(esc(n.titulo))</td><td class=\"num chico\">\(diaYMes(n.instante))</td></tr>"
        }
        return h + "</table></section>"
    }

    private static func pie() -> String {
        """
        <footer>
        Esta página la escribe la app sola cada vez que sube algo a Drive, junto con
        <code>resumen.md</code> y los CSV. No pide nada por internet: se puede abrir
        sin conexión y se puede imprimir.<br>
        Los números salen de los mismos archivos que están en la carpeta: si algo
        acá no cierra, el dato crudo está en el CSV correspondiente.
        </footer>
        </div></body></html>
        """
    }

    // MARK: - Ayuda

    private static func filaHTML(_ nombre: String, _ valor: String) -> String {
        "<tr><td>\(esc(nombre))</td><td class=\"num\">\(esc(valor))</td></tr>"
    }

    /// Escapa lo que podría romper el HTML. Las notas son texto libre.
    private static func esc(_ texto: String) -> String {
        texto
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func fmt(_ v: Double) -> String { String(format: "%.0f", v) }

    private static func coma(_ v: Double, _ decimales: Int) -> String {
        String(format: "%.\(decimales)f", v).replacingOccurrences(of: ".", with: ",")
    }

    private static func miles(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }

    private static func conSigno(_ valor: Double?) -> String {
        guard let valor else { return "—" }
        return String(format: "%+.2f kg", valor).replacingOccurrences(of: ".", with: ",")
    }

    private static func tendencia(_ puntos: [PuntoDePeso]) -> String {
        guard let porSemana = Analisis.tendenciaPorSemana(puntos) else {
            return "faltan días para la tendencia"
        }
        return String(format: "%+.2f kg por semana", porSemana).replacingOccurrences(of: ".", with: ",")
    }

    private static func comparado(_ par: Semana.Par, unidad: String) -> String {
        guard par.hayConQueComparar else { return "sin semana anterior" }
        return String(format: "%@%.0f%@ vs anterior", par.cambio >= 0 ? "+" : "−",
                      abs(par.cambio), unidad)
    }

    private static func formato(_ patron: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.dateFormat = patron
        return f
    }

    private static func fechaYHora(_ f: Date) -> String { formato("d/M/yyyy HH:mm").string(from: f) }
    private static func diaYMes(_ f: Date) -> String { formato("d MMM").string(from: f) }
    private static func inicial(_ f: Date) -> String {
        Fechas.inicialDelDia(Calendar.current.component(.weekday, from: f))
    }

    private static func enMinutos(_ segundos: Double) -> String {
        let s = Int(segundos)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private static func enHoras(_ segundos: Double) -> String {
        let horas = Int(segundos) / 3600
        let minutos = (Int(segundos) % 3600) / 60
        return horas > 0 ? "\(horas) h \(minutos) min" : "\(minutos) min"
    }
}

extension Almacen {
    /// El panel vive al lado de los CSV y sube a Drive con todo lo demás.
    var urlPanel: URL { documentos.appendingPathComponent("panel.html") }

    func escribirPanel(_ texto: String) {
        try? texto.write(to: urlPanel, atomically: true, encoding: .utf8)
    }
}
