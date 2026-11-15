import SwiftUI

/// Los colores de la app, decididos en el diseño: pantallas oscuras con
/// acento azul. Están acá y en ningún otro lado, así cambiar uno los cambia
/// en todas las pantallas.
enum Paleta {
    /// Fondo de las pantallas.
    static let fondo = Color(red: 14/255, green: 15/255, blue: 16/255)
    /// Fondo de las fichas y las tarjetas.
    static let superficie = Color(red: 23/255, green: 25/255, blue: 27/255)
    /// El borde fino de las fichas.
    static let borde = Color(red: 36/255, green: 40/255, blue: 43/255)
    /// Texto principal.
    static let texto = Color(red: 236/255, green: 234/255, blue: 230/255)
    /// Texto secundario.
    static let suave = Color(red: 140/255, green: 143/255, blue: 147/255)
    /// El azul de la marca.
    static let acento = Color(red: 28/255, green: 123/255, blue: 217/255)
}
