import Foundation
import SwiftUI

/// Le parcours d'accueil : 15 pages, une idée par page, qui se termine sur
/// le paywall. Ne s'affiche qu'au premier lancement, mais reste accessible
/// depuis les réglages.
struct OnboardingFlow: View {

    /// Vrai quand on le revoit depuis les réglages : fermable à tout moment.
    var estUneRevisite = false
    let terminer: () -> Void

    @State private var page = 1
    @State private var confettisDemo = 0

    private static let derniere = 15
    /// Le « Passer » discret n'apparaît qu'en toute fin de tunnel.
    private static let pageDuPasser = 13

    var body: some View {
        ZStack {
            FondApplication()

            VStack(spacing: 0) {
                // Le paywall porte sa propre croix de fermeture : lui
                // laisser aussi l'en-tête ferait deux sorties concurrentes.
                if page < Self.derniere {
                    enTete
                }
                contenu
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if confettisDemo > 0 {
                Confettis(declencheur: confettisDemo, couleurs: Palette.toutes[0].teintes)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Progression

    /// Retour, progression, « Passer ». Les deux extrémités occupent la
    /// même largeur même quand elles sont vides : sans cela la barre de
    /// progression se décale d'une page à l'autre.
    private var enTete: some View {
        HStack(spacing: 12) {
            if page > 1 {
                Button {
                    reculer()
                } label: {
                    Image(systemName: "chevron.left")
                        .boutonRond()
                }
                .accessibilityLabel(Text(tr("Page précédente")))
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            ProgressionSegmentee(page: page, total: Self.derniere)

            if page >= Self.pageDuPasser || estUneRevisite {
                Button {
                    avancer(vers: Self.derniere)
                } label: {
                    Text(tr("Passer"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Encre.discrete)
                        .frame(minWidth: 44, minHeight: 44)
                }
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    // MARK: Pages

    @ViewBuilder
    private var contenu: some View {
        Group {
            switch page {
            case 1: PageAccueil { avancer() }
            case 2:
                PageDemoLibre {
                    confettisDemo += 1
                } continuer: { avancer() }
            case 3:
                PageQuestionSimple(
                    rang: 1,
                    question: tr("Vous arrive-t-il d'hésiter longtemps pour des petites décisions ?"),
                    options: ReponsesOnboarding.Frequence.allCases.map { ($0.id, $0.libelle, $0.symbole) },
                    selection: ReponsesOnboarding.frequence?.id
                ) { choix in
                    ReponsesOnboarding.frequence = .init(rawValue: choix)
                    avancerApresChoix()
                }
            case 4: PageValidation { avancer() }
            case 5:
                PageDomaines { avancer() }
            case 6:
                PageDemoCiblee {
                    confettisDemo += 1
                } continuer: { avancer() }
            case 7:
                PageQuestionSimple(
                    rang: 3,
                    question: tr("Combien de temps perdez-vous par jour à hésiter ?"),
                    options: ReponsesOnboarding.TempsPerdu.allCases.map { ($0.id, $0.libelle, $0.symbole) },
                    selection: ReponsesOnboarding.tempsPerdu?.id
                ) { choix in
                    ReponsesOnboarding.tempsPerdu = .init(rawValue: choix)
                    avancerApresChoix()
                }
            case 8: PageProjection { avancer() }
            case 9: PageOrdreDePassage { avancer() }
            case 10: PagePonderation { avancer() }
            case 11:
                PageQuestionSimple(
                    rang: 4,
                    question: tr("Qui décidera avec vous ?"),
                    options: ReponsesOnboarding.Compagnie.allCases.map { ($0.id, $0.libelle, $0.symbole) },
                    selection: ReponsesOnboarding.compagnie?.id
                ) { choix in
                    ReponsesOnboarding.compagnie = .init(rawValue: choix)
                    avancerApresChoix()
                }
            case 12: PageBenefices { avancer() }
            case 13: PageEngagement { avancer() }
            case 14: PageRecapitulatif { avancer() }
            default:
                PaywallAdapte(contexte: .onboarding) { terminer() }
            }
        }
        .id(page)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: Navigation

    private func avancer(vers cible: Int? = nil) {
        withAnimation(.easeInOut(duration: 0.25)) {
            page = min(cible ?? (page + 1), Self.derniere)
        }
    }

    private func avancerApresChoix() {
        Haptiques.shared.selection()
        Task {
            try? await Task.sleep(for: .seconds(0.35))
            avancer()
        }
    }

    private func reculer() {
        withAnimation(.easeInOut(duration: 0.25)) {
            page = max(1, page - 1)
        }
    }
}
