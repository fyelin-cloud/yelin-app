import Foundation
import AVFoundation

/// Los avisos hablados mientras rema.
///
/// **Por qué existe**: remando no se puede mirar la pantalla sin romper el
/// movimiento. Un aviso cada 500 metros con el parcial alcanza para saber
/// cómo viene sin levantar la vista.
///
/// El audio se configura para **mezclarse con lo que esté sonando**: si está
/// escuchando música, el aviso se superpone y la música sigue, no se corta.
enum Voz {

    private static let hablante = AVSpeechSynthesizer()
    private static var listo = false

    private static func prepararAudio() {
        guard !listo else { return }
        listo = true
        let sesion = AVAudioSession.sharedInstance()
        try? sesion.setCategory(.playback, mode: .spokenAudio,
                                options: [.mixWithOthers, .duckOthers])
        try? sesion.setActive(true)
    }

    static func decir(_ texto: String) {
        prepararAudio()
        let frase = AVSpeechUtterance(string: texto)
        frase.voice = AVSpeechSynthesisVoice(language: "es-AR")
            ?? AVSpeechSynthesisVoice(language: "es-MX")
            ?? AVSpeechSynthesisVoice(language: "es-ES")
        frase.rate = 0.5
        frase.postUtteranceDelay = 0.2
        hablante.speak(frase)
    }

    static func callar() {
        hablante.stopSpeaking(at: .immediate)
    }

    /// "2 minutos 14" en vez de "2:14", que la voz lee como un número suelto.
    static func ritmoHablado(_ segundos: Int) -> String {
        let minutos = segundos / 60
        let resto = segundos % 60
        if minutos == 0 { return "\(resto) segundos" }
        let cuerpo = minutos == 1 ? "1 minuto" : "\(minutos) minutos"
        return resto == 0 ? cuerpo : "\(cuerpo) \(resto)"
    }
}
