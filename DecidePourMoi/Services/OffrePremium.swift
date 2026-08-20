import Foundation

/// Une offre telle que le paywall l'affiche, indépendamment de la
/// plomberie qui la fournit. C'est ce type que voient les vues : elles
/// ignorent tout de RevenueCat comme de StoreKit.
struct OffrePremium: Identifiable, Equatable, Sendable {

    enum Sorte: String, CaseIterable, Sendable {
        case mensuel
        case annuel
        case aVie

        /// Ordre d'affichage : le mensuel d'abord, puis l'annuel et l'offre à
        /// vie qui servent d'ancres de valeur.
        static let ordreDAffichage: [Sorte] = [.mensuel, .annuel, .aVie]

        /// Identifiant du produit dans App Store Connect. Il doit
        /// correspondre exactement à celui déclaré côté RevenueCat.
        var identifiantProduit: String {
            switch self {
            case .mensuel: "monthly"
            case .annuel: "yearly"
            case .aVie: "lifetime"
            }
        }

        var titre: String {
            switch self {
            case .mensuel: tr("Mensuel")
            case .annuel: tr("Annuel")
            case .aVie: tr("À vie")
            }
        }

        var estUnAbonnement: Bool { self != .aVie }

        /// Nombre de mois couverts, pour comparer les formules entre elles.
        var moisCouverts: Int? {
            switch self {
            case .mensuel: 1
            case .annuel: 12
            case .aVie: nil
            }
        }
    }

    let sorte: Sorte
    /// Prix formaté par le store, dans la devise de l'utilisateur.
    let prixAffiche: String
    /// Prix brut, pour comparer les formules. Nul si le store ne l'a pas donné.
    let prix: Decimal
    /// Vrai quand le produit porte une offre d'introduction (l'essai gratuit).
    let aUnEssai: Bool

    var id: Sorte { sorte }

    /// Libellé sous le titre de la carte.
    var detail: String {
        switch sorte {
        case .mensuel: aUnEssai ? tr("\(prixAffiche)/mois après l'essai") : tr("\(prixAffiche)/mois")
        case .annuel: aUnEssai ? tr("\(prixAffiche)/an après l'essai") : tr("\(prixAffiche)/an")
        case .aVie: tr("\(prixAffiche) une fois, à vie")
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
        case .annuel:
            aUnEssai
                ? tr("Après 3 jours d'essai gratuit, abonnement de \(prixAffiche) par an, renouvelé automatiquement. Annulable à tout moment dans les réglages de votre compte App Store.")
                : tr("Abonnement de \(prixAffiche) par an, renouvelé automatiquement. Annulable à tout moment dans les réglages de votre compte App Store.")
        }
    }

    /// Texte du bouton d'achat, qui suit la sélection.
    var texteCTA: String {
        switch sorte {
        case .mensuel, .annuel: aUnEssai ? tr("Commencer mes 3 jours gratuits") : tr("Continuer")
        case .aVie: tr("Débloquer à vie")
        }
    }

    /// Économie réalisée face à la formule mensuelle, en pourcentage entier.
    /// Nulle si la comparaison n'a pas de sens ou n'est pas avantageuse.
    func economieFaceAuMensuel(_ mensuel: OffrePremium?) -> Int? {
        guard
            let mensuel,
            let mois = sorte.moisCouverts, mois > 1,
            mensuel.prix > 0, prix > 0
        else { return nil }
        let plein = mensuel.prix * Decimal(mois)
        guard plein > prix else { return nil }
        let ratio = (plein - prix) / plein
        let pourcentage = Int((NSDecimalNumber(decimal: ratio).doubleValue * 100).rounded())
        return pourcentage >= 5 ? pourcentage : nil
    }
}
