import Foundation
import SwiftUI

/// Clés des réglages, partagées entre `@AppStorage` côté vues et les
/// lectures directes côté moteur.
enum CleReglage {
    static let son = "reglage.son"
    static let confettis = "reglage.confettis"
    static let paletteParDefaut = "reglage.paletteParDefaut"
    static let langue = "reglage.langue"
    static let debugPremium = "debug.premium"
}

/// Réglages et compteurs de l'app. Tout tient dans `UserDefaults` : aucune
/// donnée n'est collectée ni envoyée où que ce soit.
enum Reglages {

    private enum Cle {
        static let amorcageFait = "reglage.amorcageFait"
        static let onboardingFait = "onboarding.fait"
        static let utilisateurHistorique = "migration.utilisateurHistorique"
        static let evolutionAnnoncee = "migration.evolutionAnnoncee"
        static let promoMasqueeJusquA = "promo.masqueeJusquA"
        static let promoDerniereApp = "promo.derniereApp"
        static let avisNombreTirages = "avis.nombreTirages"
        static let avisJours = "avis.jours"
        static let avisDemande = "avis.demande"
    }

    private static var defaults: UserDefaults { .standard }

    // MARK: Valeurs par défaut

    /// Coupé par défaut : le son n'est pas la sensation principale, l'haptique l'est.
    static let sonParDefaut = false
    static let confettisParDefaut = true

    static var son: Bool {
        defaults.object(forKey: CleReglage.son) as? Bool ?? sonParDefaut
    }

    static var confettis: Bool {
        defaults.object(forKey: CleReglage.confettis) as? Bool ?? confettisParDefaut
    }

    static var paletteParDefaut: Int {
        defaults.integer(forKey: CleReglage.paletteParDefaut)
    }

    // MARK: Premier lancement

    static var amorcageFait: Bool {
        get { defaults.bool(forKey: Cle.amorcageFait) }
        set { defaults.set(newValue, forKey: Cle.amorcageFait) }
    }

    // MARK: Onboarding et migration freemium

    /// Vrai une fois l'onboarding parcouru (ou l'app détectée comme
    /// installation antérieure : ces utilisateurs ne le voient jamais).
    static var onboardingFait: Bool {
        get { defaults.bool(forKey: Cle.onboardingFait) }
        set { defaults.set(newValue, forKey: Cle.onboardingFait) }
    }

    /// Installation antérieure au passage en freemium : tout ce qui a été
    /// donné reste acquis.
    static var utilisateurHistorique: Bool {
        get { defaults.bool(forKey: Cle.utilisateurHistorique) }
        set { defaults.set(newValue, forKey: Cle.utilisateurHistorique) }
    }

    /// Le message « Décide pour moi évolue » ne se montre qu'une fois.
    static var evolutionAnnoncee: Bool {
        get { defaults.bool(forKey: Cle.evolutionAnnoncee) }
        set { defaults.set(newValue, forKey: Cle.evolutionAnnoncee) }
    }

    // MARK: Encart promo

    static var promoMasqueeJusquA: Date? {
        get {
            let valeur = defaults.double(forKey: Cle.promoMasqueeJusquA)
            return valeur > 0 ? Date(timeIntervalSince1970: valeur) : nil
        }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Cle.promoMasqueeJusquA) }
    }

    static var promoVisible: Bool {
        guard let jusquA = promoMasqueeJusquA else { return true }
        return Date.now >= jusquA
    }

    /// La carte se referme pour 14 jours, pas pour toujours.
    static func masquerPromo(pour jours: Int = 14) {
        promoMasqueeJusquA = Calendar.current.date(byAdding: .day, value: jours, to: .now)
    }

    static var promoDerniereApp: String? {
        get { defaults.string(forKey: Cle.promoDerniereApp) }
        set { defaults.set(newValue, forKey: Cle.promoDerniereApp) }
    }

    // MARK: Demande d'avis

    /// Enregistre un tirage et dit s'il faut demander un avis :
    /// à partir du 5ᵉ tirage réparti sur au moins 2 jours distincts.
    static func enregistrerTirageEtEvaluerAvis() -> Bool {
        guard !defaults.bool(forKey: Cle.avisDemande) else { return false }

        let nombre = defaults.integer(forKey: Cle.avisNombreTirages) + 1
        defaults.set(nombre, forKey: Cle.avisNombreTirages)

        let jour = ISO8601DateFormatter.jourSeul.string(from: .now)
        var jours = defaults.stringArray(forKey: Cle.avisJours) ?? []
        if !jours.contains(jour) {
            jours.append(jour)
            defaults.set(jours, forKey: Cle.avisJours)
        }

        guard nombre >= 5, jours.count >= 2 else { return false }
        defaults.set(true, forKey: Cle.avisDemande)
        return true
    }
}

extension ISO8601DateFormatter {
    static let jourSeul: ISO8601DateFormatter = {
        let formateur = ISO8601DateFormatter()
        formateur.formatOptions = [.withFullDate]
        return formateur
    }()
}
