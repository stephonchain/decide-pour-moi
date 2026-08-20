import AudioToolbox
import Foundation

/// Sons du système uniquement : rien à embarquer, rien à charger, et le
/// réglage est coupé par défaut.
@MainActor
final class Sons {

    static let shared = Sons()

    private static let tic: SystemSoundID = 1104
    private static let resultat: SystemSoundID = 1025

    /// Incrémenté à chaque lancer : les tics programmés d'un lancer annulé
    /// se taisent au lieu de se superposer au suivant.
    private var generation = 0

    private init() {}

    func jouerTics(_ instants: [Double], actif: Bool) {
        generation += 1
        guard actif else { return }
        let generationCourante = generation
        // Au-delà de quelques dizaines de tics par seconde, le son devient une
        // bouillie : on ne garde que ceux suffisamment espacés.
        var dernier = -1.0
        for instant in instants where instant - dernier >= 0.07 {
            dernier = instant
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(instant))
                guard let self, self.generation == generationCourante else { return }
                AudioServicesPlaySystemSound(Sons.tic)
            }
        }
    }

    func arreter() {
        generation += 1
    }

    func jouerResultat(actif: Bool) {
        guard actif else { return }
        AudioServicesPlaySystemSound(Sons.resultat)
    }
}
