import Foundation
import SwiftUI

/// Langue de l'interface, choisie dans l'app et indépendante de celle de
/// l'iPhone : on peut avoir un téléphone en anglais et vouloir cette app-ci
/// en français.
enum Langue: String, CaseIterable, Identifiable, Sendable {
    /// Suit le réglage du système, y compris la langue par app d'iOS.
    case systeme
    case francais = "fr"
    case anglais = "en"

    var id: String { rawValue }

    /// Code ISO, ou `nil` quand on suit le système.
    var code: String? { self == .systeme ? nil : rawValue }

    /// Nom affiché dans le sélecteur. Chaque langue s'écrit dans la sienne :
    /// c'est ainsi qu'on la reconnaît quand on ne comprend pas celle en cours.
    var nomAffiche: String {
        switch self {
        case .systeme: tr("Langue du système")
        case .francais: "Français"
        case .anglais: "English"
        }
    }
}

/// Résolution des chaînes selon la langue choisie.
///
/// Les valeurs sont mises en cache : `tr(_:)` est appelé à chaque rendu de
/// chaque écran, relire les réglages à chaque chaîne serait du gaspillage.
/// Lecture et écriture se font depuis l'interface, donc sur l'acteur principal.
enum Langues {

    private static var cacheLangue: Langue?
    private static var cacheBundle: Bundle?
    private static var cacheLocale: Locale?

    static var choisie: Langue {
        if let cacheLangue { return cacheLangue }
        let brute = UserDefaults.standard.string(forKey: CleReglage.langue) ?? ""
        let langue = Langue(rawValue: brute) ?? .systeme
        cacheLangue = langue
        return langue
    }

    static func choisir(_ langue: Langue) {
        UserDefaults.standard.set(langue.rawValue, forKey: CleReglage.langue)
        cacheLangue = langue
        cacheBundle = nil
        cacheLocale = nil
    }

    /// Code réellement en vigueur, système compris. Sert au catalogue promo.
    static var codeEffectif: String {
        choisie.code ?? Locale.current.language.languageCode?.identifier ?? "fr"
    }

    /// Bundle où chercher les chaînes. `Bundle.main` quand on suit le système.
    static var bundle: Bundle {
        if let cacheBundle { return cacheBundle }
        guard
            let code = choisie.code,
            let chemin = Bundle.main.path(forResource: code, ofType: "lproj"),
            let bundle = Bundle(path: chemin)
        else {
            cacheBundle = .main
            return .main
        }
        cacheBundle = bundle
        return bundle
    }

    /// Locale des dates et des nombres. On ne remplace que la langue : la
    /// région de l'utilisateur, elle, reste la sienne.
    static var locale: Locale {
        if let cacheLocale { return cacheLocale }
        guard let code = choisie.code else {
            cacheLocale = .current
            return .current
        }
        var composants = Locale.Components(locale: .current)
        composants.languageComponents = Locale.Language.Components(identifier: code)
        let locale = Locale(components: composants)
        cacheLocale = locale
        return locale
    }
}

/// Chaîne traduite dans la langue choisie dans l'app.
///
/// À utiliser partout où l'on écrirait `String(localized:)` : les vues lisent
/// la langue de l'app, pas celle du système.
func tr(_ cle: String.LocalizationValue) -> String {
    String(localized: cle, bundle: Langues.bundle, locale: Langues.locale)
}

/// Même chose, en conservant le markdown léger de la chaîne (gras, italique).
func trRiche(_ cle: String.LocalizationValue) -> AttributedString {
    AttributedString(localized: cle, bundle: Langues.bundle, locale: Langues.locale)
}
