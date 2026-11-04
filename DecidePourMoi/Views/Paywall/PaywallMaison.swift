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
    /// Abonné qui veut basculer sur l'achat unique.
    case passageAVie
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
        case .passageAVie: tr("Passez à l'achat à vie")
        case .evolution: tr("Décide pour moi évolue")
        }
    }

    var sousTitre: String? {
        switch self {
        case .onboarding:
            SousTitrePersonnalise.depuisLOnboarding()
        case .passageAVie:
            tr("Un seul paiement, plus aucun renouvellement. Après l'achat, pensez à annuler votre abonnement en cours : il ne s'arrête pas de lui-même.")
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
    var surFermeture: (() -> Void)?

    init(contexte: ContextePaywall, surFermeture: (() -> Void)? = nil) {
        self.contexte = contexte
        self.surFermeture = surFermeture
        // Qui vient basculer vers l'achat à vie n'a pas à re-choisir le
        // mensuel : la carte visée est présélectionnée.
        _selection = State(initialValue: contexte == .passageAVie ? .aVie : .mensuel)
    }

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
            roueEnFiligrane

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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

    /// La roue, à peine visible derrière le coin haut droit : elle rappelle
    /// ce qu'on achète sans disputer la place au texte.
    private var roueEnFiligrane: some View {
        VStack {
            HStack {
                Spacer()
                RoueCanvas(
                    segments: (0..<8).map { _ in SegmentAffichage(id: UUID(), label: "", poids: 1) },
                    palette: Palette.toutes[0]
                )
                .frame(width: 260, height: 260)
                .opacity(0.18)
                .offset(x: 90, y: -90)
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var entete: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(contexte.titre)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Encre.vive)
                .fixedSize(horizontal: false, vertical: true)
            if let sousTitre = contexte.sousTitre {
                Text(sousTitre)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Encre.douce)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sur deux colonnes : quatre promesses courtes se lisent d'un coup
    /// d'œil, là où quatre lignes pleine largeur repoussent les offres
    /// sous la ligne de flottaison.
    private var benefices: some View {
        let lignes = [
            tr("Roues illimitées"),
            tr("Tous les modes"),
            tr("La pondération"),
            tr("Palettes et historique")
        ]
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(lignes, id: \.self) { ligne in
                LigneBenefice(texte: ligne)
            }
        }
    }

    @ViewBuilder
    private var offres: some View {
        if !premium.offres.isEmpty {
            VStack(spacing: 14) {
                ForEach(premium.offres) { offre in
                    CarteOffre(
                        choisie: selection == offre.sorte,
                        badge: badge(pour: offre),
                        couleurDuBadge: offre.sorte == .aVie ? Accent.soleil : Palette.toutes[0].teintes[3],
                        titre: offre.sorte.titre,
                        detail: offre.detail,
                        prix: offre.prixAffiche
                    ) { choisir(offre.sorte) }
                }
            }
        } else {
            VStack(spacing: 12) {
                if premium.chargementEnCours {
                    ProgressView()
                        .tint(.white)
                    Text(tr("Chargement des offres…"))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                } else {
                    Text(premium.erreurOffre ?? tr("Aucune offre disponible pour le moment."))
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
            }
            .frame(maxWidth: .infinity)
            .carte()
        }
    }

    /// Le badge d'essai suit le produit ; « meilleure offre » revient à
    /// l'achat unique, notre ancre de valeur. L'hebdomadaire reste sobre :
    /// son rôle est de faire paraître les deux autres évidentes.
    private func badge(pour offre: OffrePremium) -> String? {
        switch offre.sorte {
        case .mensuel: offre.aUnEssai ? tr("3 JOURS GRATUITS") : nil
        case .aVie: tr("MEILLEURE OFFRE")
        case .hebdo: nil
        }
    }

    private var boutonPrincipal: some View {
        VStack(spacing: 10) {
            Button {
                acheter()
            } label: {
                Group {
                    if achatEnCours {
                        ProgressView().tint(Fond.sombre)
                    } else {
                        Text(texteCTA)
                    }
                }
                .boutonPrincipal()
            }
            .disabled(achatEnCours || offreChoisie == nil)
            .opacity(offreChoisie == nil ? 0.5 : 1)

            if let messageErreur {
                Text(messageErreur)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFF8A80))
                    .multilineTextAlignment(.center)
            }

            if let mention = offreChoisie?.mentionRenouvellement {
                Text(mention)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Encre.discrete)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var mentionsLegales: some View {
        HStack(spacing: 16) {
            Button {
                restaurer()
            } label: {
                Text(tr("Restaurer"))
            }
            .disabled(achatEnCours)

            Link(destination: Studio.urlConditions) { Text(tr("Conditions")) }
            Link(destination: Studio.urlConfidentialite) { Text(tr("Confidentialité")) }
        }
        .font(.system(size: 12, weight: .heavy, design: .rounded))
        .underline()
        .foregroundStyle(Encre.discrete)
        .frame(maxWidth: .infinity)
    }

    private var boutonFermer: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    fermer()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Encre.discrete)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08), in: .circle)
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
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Palette.toutes[0].teintes[3])
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Fond.sombre)
            }
            .frame(width: 20, height: 20)

            Text(texte)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Encre.vive)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

struct CarteOffre: View {
    let choisie: Bool
    let badge: String?
    let couleurDuBadge: Color
    let titre: String
    let detail: String
    let prix: String
    let choisir: () -> Void

    var body: some View {
        Button(action: choisir) {
            HStack(spacing: 12) {
                PastilleChoix(choisie: choisie)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titre)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Encre.vive)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Encre.discrete)
                    }
                }
                Spacer(minLength: 8)

                Text(prix)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Encre.vive)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(choisie ? Fond.carteChoisie : Fond.carte, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(choisie ? Accent.soleil : .clear, lineWidth: 2)
            }
            // Le badge déborde du haut de la carte : c'est lui qu'on voit
            // en premier, avant même d'avoir lu le nom de l'offre.
            .overlay(alignment: .topLeading) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(Fond.sombre)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(couleurDuBadge, in: .rect(cornerRadius: 10))
                        .offset(x: 16, y: -11)
                }
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
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Accent.soleil)
    }
}

/// Le même cadenas, en pastille, quand il se pose sur une vignette plutôt
/// qu'au fil du texte.
struct PastilleCadenas: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 13, weight: .black))
            .foregroundStyle(Accent.soleil)
            .frame(width: 30, height: 30)
            .background(Accent.voile, in: .circle)
    }
}
