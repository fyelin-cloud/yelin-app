import Foundation

/// Las fechas escritas como las diría una persona.
///
/// Estaba repetido en tres pantallas con criterios distintos; acá queda uno
/// solo para toda la app.
enum Fechas {

    private static func formato(_ patron: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.dateFormat = patron
        return f
    }

    /// "hoy", "ayer", "hace 3 días", y de una semana en adelante "12/11".
    static func relativa(_ fecha: Date) -> String {
        let calendario = Calendar.current
        if calendario.isDateInToday(fecha) { return "hoy" }
        if calendario.isDateInYesterday(fecha) { return "ayer" }
        let dias = calendario.dateComponents([.day],
                                             from: calendario.startOfDay(for: fecha),
                                             to: calendario.startOfDay(for: Date())).day ?? 0
        if dias > 1 && dias < 7 { return "hace \(dias) días" }
        if dias < 0 { return corta(fecha) }
        return corta(fecha)
    }

    /// Igual que `relativa`, pero si es de hoy agrega la hora.
    static func conHora(_ fecha: Date) -> String {
        if Calendar.current.isDateInToday(fecha) {
            return "hoy " + formato("HH:mm").string(from: fecha)
        }
        return relativa(fecha)
    }

    /// "12/11"
    static func corta(_ fecha: Date) -> String {
        formato("d/M").string(from: fecha)
    }

    /// "12/11/2026"
    static func conAnio(_ fecha: Date) -> String {
        formato("d/M/yyyy").string(from: fecha)
    }

    /// "Domingo 15 de noviembre"
    static func larga(_ fecha: Date) -> String {
        formato("EEEE d 'de' MMMM").string(from: fecha).capitalizedPrimera
    }

    /// "15 nov"
    static func diaYMes(_ fecha: Date) -> String {
        formato("d MMM").string(from: fecha)
    }

    /// Las tres letras del día: L, M, M, J, V, S, D ordenadas como las usa
    /// el calendario de constancia.
    static func inicialDelDia(_ numero: Int) -> String {
        ["D", "L", "M", "M", "J", "V", "S"][max(0, min(6, numero - 1))]
    }

    static func mes(_ fecha: Date) -> String {
        formato("MMM").string(from: fecha)
    }
}
