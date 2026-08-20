import CoreHaptics
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Pilote CoreHaptics. Toute la timeline des tics est jouée en un seul motif :
/// la précision ne dépend pas de la charge du thread principal.
@MainActor
final class Haptiques {

    static let shared = Haptiques()

    private var moteur: CHHapticEngine?
    private var lecteur: CHHapticPatternPlayer?
    private var supporte: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    private init() {}

    func preparer() {
        guard supporte, moteur == nil else { return }
        do {
            let moteur = try CHHapticEngine()
            moteur.playsHapticsOnly = true
            moteur.isAutoShutdownEnabled = true
            moteur.resetHandler = { [weak self] in
                Task { @MainActor in try? self?.moteur?.start() }
            }
            moteur.stoppedHandler = { _ in }
            try moteur.start()
            self.moteur = moteur
        } catch {
            moteur = nil
        }
    }

    /// Joue la série de tics de la roue. `instants` est la timeline calculée
    /// par `SpinEngine.instantsDesTics`.
    func jouerTics(_ instants: [Double], duree: Double) {
        guard supporte, !instants.isEmpty else { return }
        preparer()
        guard let moteur else { return }

        let evenements: [CHHapticEvent] = instants.map { instant in
            // Les derniers tics sont les plus francs : on sent la roue « accrocher ».
            let avancement = duree > 0 ? min(max(instant / duree, 0), 1) : 1
            let intensite = Float(0.35 + 0.55 * avancement)
            let nettete = Float(0.45 + 0.45 * avancement)
            return CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensite),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: nettete)
                ],
                relativeTime: instant
            )
        }

        do {
            let motif = try CHHapticPattern(events: evenements, parameters: [])
            try moteur.start()
            lecteur = try moteur.makePlayer(with: motif)
            try lecteur?.start(atTime: CHHapticTimeImmediate)
        } catch {
            lecteur = nil
        }
    }

    func arreterTics() {
        try? lecteur?.stop(atTime: CHHapticTimeImmediate)
        lecteur = nil
    }

    /// Impact franc à l'annonce du résultat.
    func celebration() {
        #if canImport(UIKit)
        let generateur = UIImpactFeedbackGenerator(style: .heavy)
        generateur.prepare()
        generateur.impactOccurred()
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            let leger = UIImpactFeedbackGenerator(style: .rigid)
            leger.impactOccurred(intensity: 0.7)
        }
        #endif
    }

    func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    func succes() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
