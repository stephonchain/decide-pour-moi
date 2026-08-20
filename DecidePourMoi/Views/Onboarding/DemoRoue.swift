import Foundation
import SwiftUI

/// Moteur d'une roue de démonstration : le même SpinEngine que la vraie roue,
/// les mêmes haptiques, mais aucune persistance — l'onboarding ne touche pas
/// aux données.
@MainActor
@Observable
final class DemoSpin {

    var angle: Double = 0
    private(set) var plan: SpinPlan?
    private(set) var debut: Date?
    private(set) var enRotation = false
    private(set) var resultat: String?
    private(set) var nombreDeTirages = 0

    func angleAffiche(a date: Date) -> Double {
        guard let plan, let debut, enRotation else { return angle }
        return plan.angle(a: date.timeIntervalSince(debut))
    }

    func lancer(labels: [String], vitesse: Double = 12) {
        guard !enRotation, labels.count >= 2 else { return }
        let options = labels.map { _ in SpinOption() }
        guard
            let gagnant = SpinEngine.tirer(parmi: options),
            let plan = SpinEngine.plan(options: options, indexGagnant: gagnant, angleActuel: angle, vitesseGeste: vitesse)
        else { return }

        self.plan = plan
        debut = .now
        enRotation = true
        resultat = nil

        let instants = SpinEngine.instantsDesTics(plan: plan, options: options)
        Haptiques.shared.jouerTics(instants, duree: plan.duree)

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(plan.duree))
            guard let self, self.enRotation else { return }
            self.angle = SpinEngine.modulo(plan.angleArrivee, SpinEngine.tour)
            self.enRotation = false
            self.plan = nil
            self.debut = nil
            self.resultat = labels[gagnant]
            self.nombreDeTirages += 1
            Haptiques.shared.celebration()
        }
    }
}

/// Roue interactive des pages de démonstration. Peut se lancer toute seule
/// une première fois, puis invite à un vrai tirage au doigt.
struct DemoRoue: View {

    let titre: String
    let labels: [String]
    let palette: Palette
    /// Lancement automatique à l'apparition (page 2 : la magie d'abord).
    var lancementAuto: Bool
    /// Appelé après chaque tirage *fait par l'utilisateur*.
    var surTirage: ((String) -> Void)?

    private let segments: [SegmentAffichage]

    @State private var moteur = DemoSpin()
    @State private var autoFait = false

    init(
        titre: String,
        labels: [String],
        palette: Palette,
        lancementAuto: Bool = false,
        surTirage: ((String) -> Void)? = nil
    ) {
        self.titre = titre
        self.labels = labels
        self.palette = palette
        self.lancementAuto = lancementAuto
        self.surTirage = surTirage
        self.segments = labels.map { SegmentAffichage(id: UUID(), label: $0, poids: 1) }
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(titre)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            GeometryReader { geometrie in
                let cote = min(geometrie.size.width, geometrie.size.height)
                ZStack {
                    TimelineView(.animation(paused: !moteur.enRotation)) { temps in
                        RoueCanvas(segments: segments, palette: palette)
                            .rotationEffect(.radians(moteur.angleAffiche(a: temps.date)))
                    }
                    .frame(width: cote, height: cote)
                    .shadow(color: .black.opacity(0.4), radius: 18, y: 8)

                    PointeurRoue()
                        .frame(width: cote * 0.11, height: cote * 0.17)
                        .offset(y: -cote / 2 + cote * 0.055)

                    Button {
                        lancerParLUtilisateur()
                    } label: {
                        MoyeuRoue(enRotation: moteur.enRotation, couleur: palette.teintes.first ?? .accentColor)
                            .frame(width: cote * 0.2, height: cote * 0.2)
                    }
                    .buttonStyle(.plain)
                    .disabled(moteur.enRotation)
                    .accessibilityLabel(Text(tr("Tourner la roue")))

                    if let resultat = moteur.resultat {
                        Text(resultat)
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Fond.sombreProfond.opacity(0.92), in: .capsule)
                            .offset(y: cote * 0.36)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: geometrie.size.width, height: geometrie.size.height)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: moteur.resultat)
        .task {
            guard lancementAuto, !autoFait else { return }
            autoFait = true
            try? await Task.sleep(for: .seconds(0.7))
            moteur.lancer(labels: labels, vitesse: 7)
        }
    }

    /// Nombre de tirages déclenchés par l'utilisateur (l'auto ne compte pas).
    var tiragesUtilisateur: Int {
        max(0, moteur.nombreDeTirages - (lancementAuto ? 1 : 0))
    }

    private func lancerParLUtilisateur() {
        let dejaFaits = tiragesUtilisateur
        moteur.lancer(labels: labels, vitesse: 14)
        Task {
            // Le résultat tombe à la fin de l'animation : on le guette pour
            // prévenir le flux d'onboarding.
            try? await Task.sleep(for: .seconds(SpinEngine.dureeMax + 0.3))
            if tiragesUtilisateur > dejaFaits, let resultat = moteur.resultat {
                surTirage?(resultat)
            }
        }
    }
}
