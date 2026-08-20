import Foundation
import SwiftUI

/// Une app du studio, telle que décrite dans `promo_apps.json`.
struct AppPromue: Identifiable, Hashable, Sendable {
    enum Audience: String, Codable, Sendable {
        case grandPublic
        case soignants
    }

    let id: String
    let nom: String
    /// Accroches par code de langue, telles qu'elles sont dans le catalogue.
    let accroches: [String: String]
    let url: URL
    let audience: Audience
    let poids: Int
    let symbole: String
    let couleur: Color

    /// Accroche dans la langue choisie dans l'app, français par défaut.
    var accroche: String {
        accroches[Langues.codeEffectif] ?? accroches["fr"] ?? accroches["en"] ?? ""
    }
}

/// Catalogue interne : nos propres apps, jamais de régie publicitaire tierce.
/// Rien n'est chargé depuis le réseau, le fichier est embarqué dans le bundle.
@MainActor
final class CataloguePromo {

    static let shared = CataloguePromo()

    private(set) var apps: [AppPromue] = []

    private init() {
        apps = Self.charger()
    }

    var grandPublic: [AppPromue] { apps.filter { $0.audience == .grandPublic } }
    var soignants: [AppPromue] { apps.filter { $0.audience == .soignants } }

    /// Tire l'app à mettre en avant : rotation pondérée, en évitant de
    /// remontrer celle de la dernière fois quand il y a le choix.
    func appAMettreEnAvant(evitant identifiantPrecedent: String?) -> AppPromue? {
        guard !apps.isEmpty else { return nil }
        var candidates = apps
        if candidates.count > 1, let identifiantPrecedent {
            let sansLaPrecedente = candidates.filter { $0.id != identifiantPrecedent }
            if !sansLaPrecedente.isEmpty { candidates = sansLaPrecedente }
        }
        let total = candidates.reduce(0) { $0 + max(1, $1.poids) }
        var seuil = Int.random(in: 0..<total)
        for app in candidates {
            seuil -= max(1, app.poids)
            if seuil < 0 { return app }
        }
        return candidates.last
    }

    // MARK: Chargement

    private struct Fichier: Decodable {
        let apps: [Entree]
    }

    private struct Entree: Decodable {
        let id: String
        let nom: String
        let accroche: [String: String]
        let url: String
        let audience: AppPromue.Audience
        let poids: Int
        let symbole: String
        let couleur: String
    }

    private static func charger() -> [AppPromue] {
        guard
            let adresse = Bundle.main.url(forResource: "promo_apps", withExtension: "json"),
            let donnees = try? Data(contentsOf: adresse),
            let fichier = try? JSONDecoder().decode(Fichier.self, from: donnees)
        else {
            return []
        }

        return fichier.apps.compactMap { entree -> AppPromue? in
            guard let url = URL(string: entree.url) else { return nil }
            return AppPromue(
                id: entree.id,
                nom: entree.nom,
                accroches: entree.accroche,
                url: url,
                audience: entree.audience,
                poids: entree.poids,
                symbole: entree.symbole,
                couleur: Color(hex: UInt32(entree.couleur, radix: 16) ?? 0x8B5CF6)
            )
        }
    }
}
