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
/// - **gratuit** : deux roues — « Ce soir on mange… », modifiable trois
///   fois, et « Pile ou face », figée —, tirage avec remise, deux palettes.
struct Acces: Equatable, Sendable {

    let estPremium: Bool
    /// Vrai pour une installation antérieure au passage en freemium.
    let estHistorique: Bool

    /// Palettes accessibles sans premium (Fête et Agrumes).
    static let palettesGratuites: Set<Int> = [0, 1]

    /// Nombre de roues déverrouillées permises sans premium.
    static let rouesGratuites = 1

    /// Modifications offertes en version gratuite, toutes roues confondues.
    /// Le compteur est global et non attaché à une roue : supprimer puis
    /// restaurer les roues de départ ne le remet pas à zéro.
    static let modificationsGratuites = 3

    /// Ce que l'éditeur autorise sur une roue donnée.
    enum DroitDEdition: Equatable, Sendable {
        /// Premium ou historique : aucune limite.
        case libre
        /// Gratuit : encore `restantes` modifications offertes.
        case limite(restantes: Int)
        /// Roue figée, ou modifications offertes épuisées.
        case bloque
    }

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

    /// Droit d'édition d'une roue. L'utilisateur historique garde la main
    /// sur tout, comme avant le passage en freemium. En gratuit, la roue
    /// figée (« Pile ou face ») ne se modifie jamais — elle n'a rien à
    /// personnaliser, c'est sa raison d'être —, les autres tant qu'il reste
    /// des modifications offertes.
    func droitDEdition(roueFigee: Bool, modificationsUtilisees: Int) -> DroitDEdition {
        if estPremium || estHistorique { return .libre }
        if roueFigee { return .bloque }
        let restantes = max(0, Self.modificationsGratuites - modificationsUtilisees)
        return restantes > 0 ? .limite(restantes: restantes) : .bloque
    }

    /// Ensemble des palettes autorisées, pour les sélecteurs.
    var palettesAutorisees: Set<Int> {
        estPremium || estHistorique ? Set(Palette.toutes.map(\.id)) : Self.palettesGratuites
    }
}
