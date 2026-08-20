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
                barreDeProgression
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

    private var barreDeProgression: some View {
        VStack(spacing: 0) {
            HStack {
                if page > 1, page < Self.derniere {
                    Button {
                        reculer()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: 38, height: 38)
                    }
                    .accessibilityLabel(Text(tr("Page précédente")))
                } else {
                    Color.clear.frame(width: 38, height: 38)
                }

                ProgressView(value: Double(page), total: Double(Self.derniere))
                    .tint(.white)
                    .scaleEffect(y: 0.6)

                if page >= Self.pageDuPasser && page < Self.derniere || estUneRevisite {
                    Button {
                        avancer(vers: Self.derniere)
                    } label: {
                        Text(tr("Passer"))
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(height: 38)
                    }
                } else {
                    Color.clear.frame(width: 38, height: 38)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .opacity(page == Self.derniere ? 0 : 1)
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
                    question: tr("Vous arrive-t-il d'hésiter longtemps pour des petites décisions ?"),
                    options: ReponsesOnboarding.Frequence.allCases.map { ($0.id, $0.libelle) },
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
                    question: tr("Combien de temps perdez-vous par jour à hésiter ?"),
                    options: ReponsesOnboarding.TempsPerdu.allCases.map { ($0.id, $0.libelle) },
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
                    question: tr("Qui décidera avec vous ?"),
                    options: ReponsesOnboarding.Compagnie.allCases.map { ($0.id, $0.libelle) },
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
