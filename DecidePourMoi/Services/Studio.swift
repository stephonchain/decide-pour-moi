import Foundation

/// Constantes d'édition. Tout ce qui doit être renseigné avant publication
/// est regroupé ici, à un seul endroit.
enum Studio {
    /// Adresse de contact du studio, affichée dans les réglages et sur la
    /// fiche App Store.
    static let adresseDeContact = "contact@steverover.com"

    /// Pages légales, hébergées dans le dépôt public stephonchain/legal et
    /// servies par GitHub Pages. Le texte de confidentialité intégral reste
    /// également lisible hors ligne dans l'app.
    static let urlSupport = URL(string: "https://stephonchain.github.io/legal/decide-pour-moi/")!
    static let urlConfidentialite = URL(string: "https://stephonchain.github.io/legal/decide-pour-moi/confidentialite.html")!

    /// Conditions d'utilisation propres à l'app : elles couvrent le freemium,
    /// les abonnements et l'essai gratuit, ce que l'EULA générique d'Apple ne
    /// fait pas.
    static let urlConditions = URL(string: "https://stephonchain.github.io/legal/decide-pour-moi/conditions.html")!

    /// Clé API *publique* RevenueCat de l'app App Store. Elle est conçue
    /// pour être embarquée dans l'app — elle ne donne accès qu'aux
    /// opérations d'un client, jamais au tableau de bord.
    static let cleRevenueCat = "appl_QPowcpRxwADBAHoPphucbYpOmlK"

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
