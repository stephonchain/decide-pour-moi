import Foundation

/// Réponses données pendant l'onboarding. Stockées localement, jamais
/// envoyées nulle part : elles servent à personnaliser la suite du parcours
/// et le paywall, c'est tout.
enum ReponsesOnboarding {

    private static var defaults: UserDefaults { .standard }

    // MARK: Page 3 — fréquence d'hésitation

    enum Frequence: String, CaseIterable, Identifiable {
        case toutLeTemps, souvent, parfois
        var id: String { rawValue }

        var libelle: String {
            switch self {
            case .toutLeTemps: tr("Tout le temps")
            case .souvent: tr("Souvent")
            case .parfois: tr("Parfois")
            }
        }
    }

    static var frequence: Frequence? {
        get { defaults.string(forKey: "onboarding.frequence").flatMap(Frequence.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "onboarding.frequence") }
    }

    // MARK: Page 5 — domaines d'hésitation (choix multiples)

    enum Domaine: String, CaseIterable, Identifiable {
        case repas, sorties, maison, travail, amis
        var id: String { rawValue }

        var libelle: String {
            switch self {
            case .repas: tr("Repas")
            case .sorties: tr("Films et sorties")
            case .maison: tr("Qui fait quoi à la maison")
            case .travail: tr("En classe ou au travail")
            case .amis: tr("Entre amis")
            }
        }

        var symbole: String {
            switch self {
            case .repas: "fork.knife"
            case .sorties: "popcorn.fill"
            case .maison: "house.fill"
            case .travail: "graduationcap.fill"
            case .amis: "person.3.fill"
            }
        }

        /// Complément pour les phrases du type « Pour vos repas, et pour… ».
        var complementDeNom: String {
            switch self {
            case .repas: tr("vos repas")
            case .sorties: tr("vos films et sorties")
            case .maison: tr("le partage des corvées")
            case .travail: tr("la classe et le travail")
            case .amis: tr("vos soirées entre amis")
            }
        }

        /// Contenu de la roue de démonstration ciblée (page 6).
        var demo: (titre: String, options: [String]) {
            switch self {
            case .repas:
                (tr("Ce soir on mange…"), [tr("Pizza"), tr("Sushis"), tr("Burger"), tr("Pâtes"), tr("Salade"), tr("Restes du frigo")])
            case .sorties:
                (tr("Ce soir on regarde…"), [tr("Comédie"), tr("Thriller"), tr("Documentaire"), tr("Classique"), tr("Série"), tr("Cinéma")])
            case .maison:
                (tr("Qui s'y colle ?"), [tr("Vaisselle"), tr("Courses"), tr("Poubelles"), tr("Lessive"), tr("Aspirateur"), tr("Cuisine")])
            case .travail:
                (tr("Qui passe au tableau ?"), [tr("Léa"), tr("Marco"), tr("Aïcha"), tr("Tom"), tr("Nina"), tr("Sacha")])
            case .amis:
                (tr("Qui commence ?"), [tr("Joueur 1"), tr("Joueur 2"), tr("Joueur 3"), tr("Joueur 4")])
            }
        }
    }

    static var domaines: [Domaine] {
        get {
            (defaults.stringArray(forKey: "onboarding.domaines") ?? [])
                .compactMap(Domaine.init(rawValue:))
        }
        set { defaults.set(newValue.map(\.rawValue), forKey: "onboarding.domaines") }
    }

    /// Domaine principal : le premier coché, la roue de la page 6 en dépend.
    static var domaineDominant: Domaine { domaines.first ?? .repas }

    // MARK: Page 7 — temps perdu

    enum TempsPerdu: String, CaseIterable, Identifiable {
        case moinsDe10, de10a30, plusDe30
        var id: String { rawValue }

        var libelle: String {
            switch self {
            case .moinsDe10: tr("Moins de 10 minutes")
            case .de10a30: tr("10 à 30 minutes")
            case .plusDe30: tr("Plus de 30 minutes")
            }
        }

        /// Projection mensuelle arrondie, pour la page 8.
        var heuresParMois: Int {
            switch self {
            case .moinsDe10: 3
            case .de10a30: 10
            case .plusDe30: 20
            }
        }
    }

    static var tempsPerdu: TempsPerdu? {
        get { defaults.string(forKey: "onboarding.temps").flatMap(TempsPerdu.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "onboarding.temps") }
    }

    // MARK: Page 11 — avec qui

    enum Compagnie: String, CaseIterable, Identifiable {
        case famille, amis, travail, moi
        var id: String { rawValue }

        var libelle: String {
            switch self {
            case .famille: tr("Ma famille")
            case .amis: tr("Mes amis")
            case .travail: tr("Mes élèves ou collègues")
            case .moi: tr("Juste moi")
            }
        }
    }

    static var compagnie: Compagnie? {
        get { defaults.string(forKey: "onboarding.compagnie").flatMap(Compagnie.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "onboarding.compagnie") }
    }
}
