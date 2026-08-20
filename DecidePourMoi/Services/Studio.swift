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

    /// Clé API *publique* RevenueCat (App-specific, commence par "appl_").
    /// À renseigner avant publication. Tant qu'elle ne l'est pas, l'app
    /// fonctionne intégralement en gratuit et le paywall explique que les
    /// achats sont momentanément indisponibles.
    static let cleRevenueCat = "REMPLACER_PAR_LA_CLE_PUBLIQUE_REVENUECAT"

    /// Tant que la clé n'est pas renseignée, les achats passent par StoreKit
    /// en direct : le paywall reste testable, seul le tableau de bord de
    /// conversion manque.
    static var revenueCatConfigure: Bool {
        cleRevenueCat.hasPrefix("appl_")
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
