import Foundation

/// Une offre telle que le paywall l'affiche, indépendamment de la
/// plomberie qui la fournit. C'est ce type que voient les vues : elles
/// ignorent tout de RevenueCat comme de StoreKit.
struct OffrePremium: Identifiable, Equatable, Sendable {

    enum Sorte: String, CaseIterable, Sendable {
        case mensuel
        case aVie
        case hebdo

        /// Ordre d'affichage : le mensuel d'abord puisqu'il est
        /// présélectionné, l'offre à vie en ancre de valeur, et
        /// l'hebdomadaire en dernier — son rôle est de rendre les deux
        /// autres évidentes.
        static let ordreDAffichage: [Sorte] = [.mensuel, .aVie, .hebdo]

        /// Identifiant du produit. Il doit correspondre **exactement** à
        /// celui déclaré dans App Store Connect et dans RevenueCat.
        var identifiantProduit: String {
            switch self {
            case .mensuel: "monthly"
            case .aVie: "lifetime"
            case .hebdo: "weekly"
            }
        }

        var titre: String {
            switch self {
            case .mensuel: tr("Mensuel")
            case .aVie: tr("À vie")
            case .hebdo: tr("Hebdomadaire")
            }
        }

        var estUnAbonnement: Bool { self != .aVie }
    }

    let sorte: Sorte
    /// Prix formaté par le store, dans la devise de l'utilisateur.
    let prixAffiche: String
    /// Vrai quand le produit porte une offre d'introduction (l'essai gratuit).
    let aUnEssai: Bool

    var id: Sorte { sorte }

    /// Libellé sous le titre de la carte.
    var detail: String {
        switch sorte {
        case .mensuel: aUnEssai ? tr("\(prixAffiche)/mois après l'essai") : tr("\(prixAffiche)/mois")
        case .aVie: tr("\(prixAffiche) une fois, à vie")
        case .hebdo: tr("\(prixAffiche)/semaine")
        }
    }

    /// Mention obligatoire sous le bouton d'achat : prix réel après l'essai,
    /// renouvellement automatique, annulation. Rien à mentionner pour un
    /// achat unique.
    var mentionRenouvellement: String? {
        switch sorte {
        case .aVie:
            nil
        case .mensuel:
            aUnEssai
                ? tr("Après 3 jours d'essai gratuit, abonnement de \(prixAffiche) par mois, renouvelé automatiquement. Annulable à tout moment dans les réglages de votre compte App Store.")
                : tr("Abonnement de \(prixAffiche) par mois, renouvelé automatiquement. Annulable à tout moment dans les réglages de votre compte App Store.")
        case .hebdo:
            tr("Abonnement de \(prixAffiche) par semaine, renouvelé automatiquement. Annulable à tout moment dans les réglages de votre compte App Store.")
        }
    }

    /// Texte du bouton d'achat, qui suit la sélection.
    var texteCTA: String {
        switch sorte {
        case .mensuel: aUnEssai ? tr("Commencer mes 3 jours gratuits") : tr("Continuer")
        case .aVie: tr("Débloquer à vie")
        case .hebdo: tr("Continuer")
        }
    }
}
