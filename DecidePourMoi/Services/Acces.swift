import Foundation

/// La matrice gratuit / premium, en un seul endroit et en logique pure :
/// chaque règle est testable sans RevenueCat ni SwiftUI.
///
/// Trois niveaux d'accès :
/// - **premium** : tout est débloqué.
/// - **historique** : utilisateur de la version gratuite d'origine. Ce qui a
///   été donné ne se reprend pas : ses roues et toutes leurs fonctions
///   restent utilisables ; seule la création de nouvelles roues passe sous
///   la limite gratuite.
/// - **gratuit** : une roue, tirage avec remise, deux palettes.
struct Acces: Equatable, Sendable {

    let estPremium: Bool
    /// Vrai pour une installation antérieure au passage en freemium.
    let estHistorique: Bool

    /// Palettes accessibles sans premium (Fête et Agrumes).
    static let palettesGratuites: Set<Int> = [0, 1]

    /// Nombre de roues déverrouillées permises sans premium.
    static let rouesGratuites = 1

    // MARK: Règles

    /// Les modes sans remise et ordre de passage sont premium.
    func modeAutorise(_ mode: ModeTirage) -> Bool {
        estPremium || estHistorique || mode == .avecRemise
    }

    /// La pondération des options (×2, ×3) est premium.
    var ponderationAutorisee: Bool { estPremium || estHistorique }

    func paletteAutorisee(_ id: Int) -> Bool {
        estPremium || estHistorique || Self.palettesGratuites.contains(id)
    }

    /// L'historique des tirages est premium.
    var historiqueAutorise: Bool { estPremium || estHistorique }

    /// Retirer une option à la volée bascule en mode sans remise : même règle.
    var retraitAutorise: Bool { modeAutorise(.sansRemise) }

    /// Une roue verrouillée (préinstallée en teaser) ne s'ouvre qu'en premium.
    func peutOuvrir(_ roue: Roue) -> Bool {
        estPremium || !roue.verrouillee
    }

    /// Créer, importer ou dupliquer une roue. La création passe sous la
    /// limite gratuite pour tout le monde, utilisateurs historiques compris :
    /// ils gardent leurs roues existantes, qui les placent de fait au-dessus
    /// de la limite, mais rien ne leur est retiré.
    func peutCreerRoue(rouesDeverrouillees nombre: Int) -> Bool {
        estPremium || nombre < Self.rouesGratuites
    }

    /// Ensemble des palettes autorisées, pour les sélecteurs.
    var palettesAutorisees: Set<Int> {
        estPremium || estHistorique ? Set(Palette.toutes.map(\.id)) : Self.palettesGratuites
    }
}
