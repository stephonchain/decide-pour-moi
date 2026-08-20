import Foundation

/// Constantes d'édition. Tout ce qui doit être renseigné avant publication
/// est regroupé ici, à un seul endroit.
enum Studio {
    /// Adresse affichée dans les réglages et sur la fiche App Store.
    /// À remplacer par l'adresse de contact réelle avant publication.
    static let adresseDeContact = "contact@decidepourmoi.app"

    /// Page publique de politique de confidentialité, exigée par App Store
    /// Connect. Le texte intégral est également lisible hors ligne dans l'app.
    static let urlConfidentialite = URL(string: "https://decidepourmoi.app/confidentialite")!

    /// Conditions d'utilisation : l'EULA standard d'Apple, obligatoire sur le
    /// paywall. À remplacer si le studio publie ses propres conditions.
    static let urlConditions = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Clé API *publique* RevenueCat. Elle est conçue pour être embarquée
    /// dans l'app — elle ne donne accès qu'aux opérations d'un client.
    /// `test_…` cible le Test Store de RevenueCat, `appl_…` l'App Store réel :
    /// c'est cette dernière qu'il faudra mettre avant publication.
    static let cleRevenueCat = "test_zWemjqxYpBrGdZiONoJLedOaDtl"

    /// Identifiant de l'entitlement dans le tableau de bord RevenueCat.
    ///
    /// Attention : c'est l'**identifiant**, pas le nom affiché. Les deux
    /// coexistent dans le tableau de bord et une confusion entre eux se
    /// traduit par un premium qui ne se déverrouille jamais. En build de
    /// développement, `PremiumManager` journalise les identifiants réellement
    /// reçus pour rendre l'écart visible immédiatement.
    static let entitlementPremium = "Décide pour moi Pro"

    /// Faux uniquement si la clé n'a pas été renseignée : les achats passent
    /// alors par StoreKit en direct, ce qui garde le paywall testable.
    static var revenueCatConfigure: Bool {
        cleRevenueCat.hasPrefix("appl_") || cleRevenueCat.hasPrefix("test_")
    }

    static var versionAffichee: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    static var lienDeContact: URL? {
        var composants = URLComponents()
        composants.scheme = "mailto"
        composants.path = adresseDeContact
        composants.queryItems = [
            URLQueryItem(name: "subject", value: "Décide pour moi \(versionAffichee)")
        ]
        return composants.url
    }
}
