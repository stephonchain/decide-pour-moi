import Foundation
import SwiftData
import SwiftUI

/// Pilote un lancer : tire le gagnant, construit le plan, lance haptiques et
/// son, puis enregistre le résultat. La vue ne fait que suivre.
@MainActor
@Observable
final class ControleurDeRoue {

    /// Angle de repos de la roue, en radians (sens horaire).
    var angle: Double = 0
    private(set) var plan: SpinPlan?
    private(set) var debut: Date?
    private(set) var enRotation = false

    /// Option gagnante à annoncer, ou nil si aucun résultat en attente.
    var resultat: OptionRoue?
    /// Nombre de lancers de cette session, sert à relancer les confettis.
    private(set) var compteurResultats = 0

    private var tacheDeFin: Task<Void, Never>?

    // MARK: Lecture pendant l'animation

    func angleAffiche(a date: Date) -> Double {
        guard let plan, let debut, enRotation else { return angle }
        return plan.angle(a: date.timeIntervalSince(debut))
    }

    /// Place la roue de sorte qu'un segment, et non une séparation, se
    /// trouve sous le pointeur à l'ouverture.
    func positionnerAuRepos(options: [SpinOption]) {
        guard !enRotation, angle == 0, let premier = SpinEngine.spans(options).first else { return }
        angle = SpinEngine.modulo(-premier.centre, SpinEngine.tour)
    }

    // MARK: Lancer

    /// Lance la roue. `vitesseGeste` vaut 0 pour un tap sur le moyeu.
    func lancer(roue: Roue, vitesseGeste: Double, contexte: ModelContext, apresLeTirage: @escaping () -> Void) {
        guard !enRotation else { return }
        let options = roue.optionsMoteur
        guard options.count >= 1 else { return }

        guard
            let indexGagnant = SpinEngine.tirer(parmi: options),
            let plan = SpinEngine.plan(
                options: options,
                indexGagnant: indexGagnant,
                angleActuel: angle,
                vitesseGeste: vitesseGeste
            )
        else { return }

        let actives = roue.optionsActives
        guard actives.indices.contains(indexGagnant) else { return }
        let gagnante = actives[indexGagnant]

        self.plan = plan
        self.debut = .now
        self.enRotation = true
        self.resultat = nil

        let instants = SpinEngine.instantsDesTics(plan: plan, options: options)
        Haptiques.shared.jouerTics(instants, duree: plan.duree)
        Sons.shared.jouerTics(instants, actif: Reglages.son)

        tacheDeFin?.cancel()
        tacheDeFin = Task { [weak self] in
            try? await Task.sleep(for: .seconds(plan.duree))
            guard !Task.isCancelled else { return }
            self?.terminer(roue: roue, gagnante: gagnante, contexte: contexte, apresLeTirage: apresLeTirage)
        }
    }

    /// Relance en gardant l'élan visuel : même geste que « Relancer ».
    func relancer(roue: Roue, contexte: ModelContext, apresLeTirage: @escaping () -> Void) {
        resultat = nil
        lancer(roue: roue, vitesseGeste: 14, contexte: contexte, apresLeTirage: apresLeTirage)
    }

    // MARK: Fin de lancer

    private func terminer(roue: Roue, gagnante: OptionRoue, contexte: ModelContext, apresLeTirage: @escaping () -> Void) {
        if let plan {
            angle = SpinEngine.modulo(plan.angleArrivee, SpinEngine.tour)
        }
        enRotation = false
        self.plan = nil
        self.debut = nil

        let tirage = Tirage(
            label: gagnante.label,
            faitPartieDeLOrdre: roue.mode == .ordreDePassage
        )
        contexte.insert(tirage)
        // La relation inverse renseigne `tirage.roue` toute seule.
        roue.historique = (roue.historique ?? []) + [tirage]
        elaguerHistorique(roue, contexte: contexte)

        if roue.mode.retireLOptionTiree {
            gagnante.retiree = true
        }
        roue.utiliseeLe = .now

        resultat = gagnante
        compteurResultats += 1

        Haptiques.shared.celebration()
        Sons.shared.jouerResultat(actif: Reglages.son)
        annoncer(gagnante.label)
        apresLeTirage()
    }

    /// L'historique reste léger : 50 tirages par roue, pas un de plus.
    private func elaguerHistorique(_ roue: Roue, contexte: ModelContext) {
        let tirages = roue.historiqueRecent
        guard tirages.count > 50 else { return }
        for tirage in tirages.dropFirst(50) {
            roue.historique?.removeAll { $0.id == tirage.id }
            contexte.delete(tirage)
        }
    }

    private func annoncer(_ label: String) {
        let phrase = tr("Résultat : \(label)")
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            AccessibilityNotification.Announcement(phrase).post()
        }
    }

    // MARK: Geste

    /// Applique la rotation du doigt pendant le glissement.
    func suivreLeDoigt(delta: Double) {
        guard !enRotation else { return }
        angle = SpinEngine.modulo(angle + delta, SpinEngine.tour)
    }

    func annulerLancer() {
        tacheDeFin?.cancel()
        tacheDeFin = nil
        Haptiques.shared.arreterTics()
        Sons.shared.arreter()
        if let plan { angle = SpinEngine.modulo(plan.angleArrivee, SpinEngine.tour) }
        enRotation = false
        plan = nil
        debut = nil
    }

    /// Vitesse angulaire minimale, en rad/s, pour qu'un swipe déclenche un lancer.
    static let vitesseDeclenchement: Double = 1.6
}
