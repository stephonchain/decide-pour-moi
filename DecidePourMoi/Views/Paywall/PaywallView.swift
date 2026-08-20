import Foundation
import RevenueCat
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

/// Le paywall. Une seule implémentation pour l'onboarding et tous les
/// déclencheurs de l'app.
struct PaywallView: View {

    let contexte: ContextePaywall
    /// L'onboarding gère lui-même sa fermeture (dernier écran du flux).
    var surFermeture: (() -> Void)? = nil

    @Environment(\.dismiss) private var fermerFeuille
    @State private var premium = PremiumManager.shared
    @State private var selection: ChoixOffre = .mensuel
    @State private var achatEnCours = false
    @State private var messageErreur: String? = nil
    @State private var croixVisible = false
    @State private var celebration = false

    enum ChoixOffre { case hebdo, mensuel, aVie }

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
        if premium.offre != nil {
            VStack(spacing: 10) {
                CarteOffre(
                    choisie: selection == .mensuel,
                    badge: premium.essaiDisponible ? tr("3 JOURS GRATUITS") : nil,
                    titre: tr("Mensuel"),
                    detail: libelleMensuel
                ) { choisir(.mensuel) }

                CarteOffre(
                    choisie: selection == .aVie,
                    badge: tr("MEILLEURE OFFRE"),
                    titre: tr("À vie"),
                    detail: libelleAVie
                ) { choisir(.aVie) }

                CarteOffre(
                    choisie: selection == .hebdo,
                    badge: nil,
                    titre: tr("Hebdomadaire"),
                    detail: libelleHebdo
                ) { choisir(.hebdo) }
            }
        } else {
            VStack(spacing: 12) {
                if premium.configure {
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
                } else {
                    Text(tr("Les achats sont momentanément indisponibles. Réessayez plus tard — tout le reste de l'app fonctionne."))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .carte()
        }
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
            .disabled(achatEnCours || packageChoisi == nil)
            .opacity(packageChoisi == nil ? 0.5 : 1)

            if let messageErreur {
                Text(messageErreur)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFF8A80))
                    .multilineTextAlignment(.center)
            }

            if selection != .aVie, let mention = mentionRenouvellement {
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
            .disabled(achatEnCours || !premium.configure)

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

    // MARK: Libellés dynamiques (jamais de prix en dur : ils viennent du store)

    private var packageChoisi: Package? {
        switch selection {
        case .hebdo: premium.packageHebdo
        case .mensuel: premium.packageMensuel
        case .aVie: premium.packageAVie
        }
    }

    private var libelleMensuel: String {
        guard let prix = premium.packageMensuel?.storeProduct.localizedPriceString else { return "" }
        return premium.essaiDisponible
            ? tr("\(prix)/mois après l'essai")
            : tr("\(prix)/mois")
    }

    private var libelleAVie: String {
        guard let prix = premium.packageAVie?.storeProduct.localizedPriceString else { return "" }
        return tr("\(prix) une fois, à vie")
    }

    private var libelleHebdo: String {
        guard let prix = premium.packageHebdo?.storeProduct.localizedPriceString else { return "" }
        return tr("\(prix)/semaine")
    }

    private var texteCTA: String {
        switch selection {
        case .mensuel: premium.essaiDisponible ? tr("Commencer mes 3 jours gratuits") : tr("Continuer")
        case .aVie: tr("Débloquer à vie")
        case .hebdo: tr("Continuer")
        }
    }

    /// Mention obligatoire : le prix réel après l'essai, le renouvellement
    /// automatique et l'annulation, sans ambiguïté.
    private var mentionRenouvellement: String? {
        switch selection {
        case .mensuel:
            guard let prix = premium.packageMensuel?.storeProduct.localizedPriceString else { return nil }
            return premium.essaiDisponible
                ? tr("Après 3 jours d'essai gratuit, abonnement de \(prix) par mois, renouvelé automatiquement. Annulable à tout moment dans les réglages de votre compte App Store.")
                : tr("Abonnement de \(prix) par mois, renouvelé automatiquement. Annulable à tout moment dans les réglages de votre compte App Store.")
        case .hebdo:
            guard let prix = premium.packageHebdo?.storeProduct.localizedPriceString else { return nil }
            return tr("Abonnement de \(prix) par semaine, renouvelé automatiquement. Annulable à tout moment dans les réglages de votre compte App Store.")
        case .aVie:
            return nil
        }
    }

    // MARK: Actions

    private func choisir(_ choix: ChoixOffre) {
        selection = choix
        Haptiques.shared.selection()
    }

    private func acheter() {
        guard let package = packageChoisi, !achatEnCours else { return }
        achatEnCours = true
        messageErreur = nil
        Task {
            defer { achatEnCours = false }
            do {
                let resultat = try await premium.acheter(package)
                if resultat == .achete { feter() }
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
