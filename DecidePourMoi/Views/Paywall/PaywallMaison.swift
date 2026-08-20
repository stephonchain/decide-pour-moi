import Foundation
import SwiftUI

/// D'où vient l'utilisateur : le paywall adapte son titre au contexte,
/// on ne vend pas la même chose à qui veut créer une deuxième roue et à
/// qui sort de l'onboarding.
enum ContextePaywall: Equatable, Identifiable {
    case onboarding
    case creationDeRoue
    case modeDeTirage
    case ponderation
    case historique
    case palette
    case roueVerrouillee
    case reglages
    /// Utilisateur historique découvrant le passage en freemium.
    case evolution

    var id: String { String(describing: self) }

    var titre: String {
        switch self {
        case .onboarding, .reglages: tr("Débloquez tout Décide pour moi")
        case .creationDeRoue: tr("Créez autant de roues que vous voulez")
        case .modeDeTirage: tr("Débloquez tous les modes de tirage")
        case .ponderation: tr("Pondérez vos options")
        case .historique: tr("Retrouvez tous vos tirages")
        case .palette: tr("Toutes les palettes de couleurs")
        case .roueVerrouillee: tr("Débloquez toutes les roues")
        case .evolution: tr("Décide pour moi évolue")
        }
    }

    var sousTitre: String? {
        switch self {
        case .onboarding:
            SousTitrePersonnalise.depuisLOnboarding()
        case .evolution:
            tr("Vos roues et tout ce que vous utilisiez restent à vous. Le premium débloque la création de nouvelles roues et tout le reste, pour toujours.")
        default:
            nil
        }
    }
}

/// Le sous-titre du paywall d'onboarding reprend les réponses données :
/// c'est pour ça qu'on les a demandées.
enum SousTitrePersonnalise {
    static func depuisLOnboarding() -> String? {
        let domaines = ReponsesOnboarding.domaines
        guard let premier = domaines.first else { return nil }
        return tr("Pour \(premier.complementDeNom), et pour tout le reste.")
    }
}

/// Le paywall maison : une seule implémentation pour l'onboarding et tous
/// les déclencheurs de l'app.
///
/// Il porte deux choses que le paywall distant de RevenueCat ne sait pas
/// faire : un titre qui change selon l'écran d'où l'on vient, et une
/// traduction pilotée par la langue choisie dans l'app plutôt que par celle
/// du système.
struct PaywallMaison: View {

    let contexte: ContextePaywall
    /// L'onboarding gère lui-même sa fermeture (dernier écran du flux).
    var surFermeture: (() -> Void)? = nil

    @Environment(\.dismiss) private var fermerFeuille
    @State private var premium = PremiumManager.shared
    @State private var selection: OffrePremium.Sorte = .mensuel
    @State private var achatEnCours = false
    @State private var messageErreur: String? = nil
    @State private var croixVisible = false
    @State private var celebration = false

    var body: some View {
        ZStack {
            FondApplication()

            ScrollView {
                VStack(spacing: 22) {
                    entete
                    benefices
                    offres
                    boutonPrincipal
                    mentionsLegales
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)
                .padding(.bottom, 24)
            }

            boutonFermer

            if celebration {
                Confettis(declencheur: 1, couleurs: Palette.toutes[0].teintes)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(achatEnCours)
        .task {
            await premium.chargerOffre()
            recalerLaSelection()
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeIn(duration: 0.4)) { croixVisible = true }
        }
        .onChange(of: premium.estPremiumEffectif) { _, actif in
            if actif { feter() }
        }
    }

    // MARK: Sections

    private var entete: some View {
        VStack(spacing: 10) {
            Text(contexte.titre)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if let sousTitre = contexte.sousTitre {
                Text(sousTitre)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var benefices: some View {
        VStack(alignment: .leading, spacing: 12) {
            LigneBenefice(texte: tr("Des roues illimitées"))
            LigneBenefice(texte: tr("Tous les modes : sans remise, ordre de passage"))
            LigneBenefice(texte: tr("La pondération des options"))
            LigneBenefice(texte: tr("L'historique de vos tirages"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .carte()
    }

    @ViewBuilder
    private var offres: some View {
        if !premium.offres.isEmpty {
            VStack(spacing: 10) {
                ForEach(premium.offres) { offre in
                    CarteOffre(
                        choisie: selection == offre.sorte,
                        badge: badge(pour: offre),
                        titre: offre.sorte.titre,
                        detail: offre.detail
                    ) { choisir(offre.sorte) }
                }
            }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text(premium.erreurOffre ?? tr("Chargement des offres…"))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                Button {
                    Task { await premium.chargerOffre() }
                } label: {
                    Text(tr("Réessayer"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .carte()
        }
    }

    /// Le badge d'essai suit le produit ; l'annuel affiche son économie
    /// réelle face au mensuel, et « meilleure offre » revient à l'achat
    /// unique, notre ancre de valeur.
    private func badge(pour offre: OffrePremium) -> String? {
        switch offre.sorte {
        case .mensuel:
            return offre.aUnEssai ? tr("3 JOURS GRATUITS") : nil
        case .annuel:
            guard let economie = offre.economieFaceAuMensuel(offreMensuelle) else {
                return offre.aUnEssai ? tr("3 JOURS GRATUITS") : nil
            }
            // Le pourcentage est assemblé à part : un « % » collé à un
            // spécificateur de format dans une chaîne traduite est ambigu.
            let pourcentage = "\(economie)\u{202F}%"
            return tr("ÉCONOMISEZ \(pourcentage)")
        case .aVie:
            return tr("MEILLEURE OFFRE")
        }
    }

    private var offreMensuelle: OffrePremium? {
        premium.offres.first { $0.sorte == .mensuel }
    }

    private var boutonPrincipal: some View {
        VStack(spacing: 10) {
            Button {
                acheter()
            } label: {
                Group {
                    if achatEnCours {
                        ProgressView().tint(Fond.sombreProfond)
                    } else {
                        Text(texteCTA)
                    }
                }
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Fond.sombreProfond)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white, in: .capsule)
            }
            .disabled(achatEnCours || offreChoisie == nil)
            .opacity(offreChoisie == nil ? 0.5 : 1)

            if let messageErreur {
                Text(messageErreur)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFF8A80))
                    .multilineTextAlignment(.center)
            }

            if let mention = offreChoisie?.mentionRenouvellement {
                Text(mention)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var mentionsLegales: some View {
        HStack(spacing: 14) {
            Button {
                restaurer()
            } label: {
                Text(tr("Restaurer mes achats"))
            }
            .disabled(achatEnCours)

            Link(destination: Studio.urlConditions) { Text(tr("Conditions")) }
            Link(destination: Studio.urlConfidentialite) { Text(tr("Confidentialité")) }
        }
        .font(.system(.caption, design: .rounded))
        .foregroundStyle(.white.opacity(0.55))
    }

    private var boutonFermer: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    fermer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.1), in: .circle)
                }
                .accessibilityLabel(Text(tr("Fermer")))
                .opacity(croixVisible ? 1 : 0)
                .disabled(!croixVisible || achatEnCours)
            }
            Spacer()
        }
        .padding(16)
    }

    // MARK: Lecture de l'offre sélectionnée

    private var offreChoisie: OffrePremium? {
        premium.offres.first { $0.sorte == selection }
    }

    private var texteCTA: String {
        offreChoisie?.texteCTA ?? tr("Continuer")
    }

    /// Garde la sélection sur une offre qui existe vraiment : pendant la
    /// configuration, l'offering peut n'en contenir qu'une partie.
    private func recalerLaSelection() {
        guard let premiere = premium.offres.first else { return }
        if !premium.offres.contains(where: { $0.sorte == selection }) {
            selection = premiere.sorte
        }
    }

    // MARK: Actions

    private func choisir(_ choix: OffrePremium.Sorte) {
        selection = choix
        Haptiques.shared.selection()
    }

    private func acheter() {
        guard offreChoisie != nil, !achatEnCours else { return }
        achatEnCours = true
        messageErreur = nil
        Task {
            defer { achatEnCours = false }
            do {
                if try await premium.acheter(selection) == .achete { feter() }
            } catch {
                messageErreur = error.localizedDescription
            }
        }
    }

    private func restaurer() {
        guard !achatEnCours else { return }
        achatEnCours = true
        messageErreur = nil
        Task {
            defer { achatEnCours = false }
            do {
                if try await premium.restaurer() {
                    feter()
                } else {
                    messageErreur = tr("Aucun achat à restaurer sur ce compte.")
                }
            } catch {
                messageErreur = error.localizedDescription
            }
        }
    }

    private func feter() {
        guard !celebration else { return }
        celebration = true
        Haptiques.shared.celebration()
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            fermer()
        }
    }

    private func fermer() {
        if let surFermeture {
            surFermeture()
        } else {
            fermerFeuille()
        }
    }
}

// MARK: - Composants

struct LigneBenefice: View {
    let texte: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: 0x4BC46B))
            Text(texte)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

struct CarteOffre: View {
    let choisie: Bool
    let badge: String?
    let titre: String
    let detail: String
    let choisir: () -> Void

    var body: some View {
        Button(action: choisir) {
            HStack(spacing: 12) {
                Image(systemName: choisie ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(choisie ? .white : .white.opacity(0.4))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(titre)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(Fond.sombreProfond)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(hex: 0xFFD53E), in: .capsule)
                        }
                    }
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(.white.opacity(choisie ? 0.14 : 0.06), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(choisie ? 0.85 : 0), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(choisie ? [.isSelected] : [])
    }
}

/// Petit cadenas posé sur les éléments premium : tout est visible, rien
/// n'est caché, mais on sait ce qui est verrouillé.
struct Cadenas: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white.opacity(0.65))
    }
}
