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
