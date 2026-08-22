import SwiftData
import Foundation
import SwiftUI

/// Racine de l'app : installe les roues du premier lancement puis affiche
/// directement la dernière roue utilisée. Aucun écran d'accueil, aucun tunnel.
struct RacineView: View {

    @Environment(\.modelContext) private var contexte
    @Query(sort: \Roue.utiliseeLe, order: .reverse) private var roues: [Roue]

    @State private var amorcageTente = false
    @State private var onboardingVisible = false
    @State private var premium = PremiumManager.shared

    /// La dernière roue utilisée *que l'utilisateur a le droit d'ouvrir* :
    /// une roue teaser verrouillée ne doit jamais devenir l'écran d'accueil.
    private var roueCourante: Roue? {
        roues.first { premium.acces.peutOuvrir($0) } ?? roues.first
    }

    var body: some View {
        ZStack {
            FondApplication()

            if let roue = roueCourante {
                EcranRoue(roue: roue)
                    .id(roue.id)
                    .transition(.opacity)
            } else if amorcageTente {
                AucuneRoueView { creerUneRoueDeSecours() }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: roueCourante?.id)
        .task { amorcer() }
        .fullScreenCover(isPresented: $onboardingVisible) {
            OnboardingFlow {
                Reglages.onboardingFait = true
                onboardingVisible = false
            }
        }
    }

    private func amorcer() {
        guard !amorcageTente else { return }
        amorcageTente = true

#if DEBUG
        // Parcours de captures : le contenu a déjà été remis à neuf au
        // démarrage, dans la langue du moment. Ni onboarding, ni
        // retraduction, ni amorçage à refaire.
        if RouesDeDemo.demandees {
            Reglages.amorcageFait = true
            Reglages.onboardingFait = true
            return
        }
#endif

        if !Reglages.amorcageFait {
            // Installation neuve : les roues secondaires sont des teasers
            // verrouillés, et l'onboarding s'ouvre par-dessus.
            if roues.isEmpty {
                RouesParDefaut.creer(dans: contexte, verrouillerSecondaires: true)
                try? contexte.save()
            }
            Reglages.amorcageFait = true
        } else if !Reglages.onboardingFait && !Reglages.utilisateurHistorique {
            // Installation antérieure au freemium : tout ce qui a été donné
            // reste acquis, et ces utilisateurs ne voient pas l'onboarding.
            // Ils découvriront l'évolution via le paywall contextuel.
            Reglages.utilisateurHistorique = true
            Reglages.onboardingFait = true
        }

        if !Reglages.onboardingFait {
            onboardingVisible = true
        }

        // Les roues préinstallées jamais modifiées suivent la langue de
        // l'app ; celles que l'utilisateur a touchées lui appartiennent.
        RouesParDefaut.retraduire(roues)
    }

    private func creerUneRoueDeSecours() {
        RouesParDefaut.creer(dans: contexte, verrouillerSecondaires: !premium.acces.estPremium && !premium.acces.estHistorique)
        try? contexte.save()
    }
}

struct AucuneRoueView: View {
    let restaurer: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 54))
                .foregroundStyle(.white.opacity(0.8))
            Text(tr("Aucune roue"))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(tr("Remettez les roues de départ pour recommencer."))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button(action: restaurer) {
                Label(tr("Restaurer les roues de départ"), systemImage: "arrow.counterclockwise")
                    .boutonPrincipal()
            }
        }
        .padding(30)
    }
}
