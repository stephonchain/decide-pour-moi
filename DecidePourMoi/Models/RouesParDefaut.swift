import Foundation
import SwiftData

/// Roues installées au premier lancement. Elles sont ensuite modifiables et
/// supprimables comme n'importe quelle roue créée par l'utilisateur.
enum RouesParDefaut {

    /// Langues dans lesquelles l'app sait reconnaître ses propres graines.
    private static let codesConnus = ["fr", "en"]

    /// Définition d'une roue préinstallée, indépendante de la langue.
    struct Graine {
        let titre: String.LocalizationValue
        let options: [String.LocalizationValue]
        let palette: Int
    }

    static let graines: [Graine] = [
        Graine(
            titre: "Ce soir on mange…",
            options: ["Pizza", "Sushis", "Burger", "Pâtes", "Salade", "Restes du frigo"],
            palette: 0
        ),
        Graine(titre: "Oui / Non", options: ["Oui", "Non"], palette: 2),
        Graine(titre: "Pile ou face", options: ["Pile", "Face"], palette: 5),
        Graine(
            titre: "Chiffres 1 à 10",
            options: (1...10).map { "\($0)" },
            palette: 1
        ),
        Graine(
            titre: "Qui commence ?",
            options: (1...4).map { "Joueur \($0)" },
            palette: 3
        )
    ]

    static func creer(dans contexte: ModelContext, verrouillerSecondaires: Bool = false) {
        for (index, graine) in graines.enumerated() {
            let options = graine.options.enumerated().map { position, cle in
                OptionRoue(label: tr(cle), ordre: position)
            }
            let roue = Roue(titre: tr(graine.titre), options: options, paletteID: graine.palette)
            roue.verrouillee = verrouillerSecondaires && index > 0
            // La première roue de la liste doit être celle qui s'ouvre au lancement.
            roue.utiliseeLe = Date(timeIntervalSinceNow: -Double(index))
            roue.creeeLe = roue.utiliseeLe
            contexte.insert(roue)
        }
    }

    /// Aligne sur la langue courante les roues préinstallées **jamais
    /// modifiées**. Une roue est reconnue comme intacte quand son titre et
    /// toutes ses options correspondent exactement à une graine dans l'une
    /// des langues connues ; au moindre texte changé par l'utilisateur, elle
    /// lui appartient et ne bouge plus jamais.
    ///
    /// Seuls les libellés sont réécrits : mode, poids, palette, historique et
    /// options déjà tirées restent tels quels.
    static func retraduire(_ roues: [Roue]) {
        for roue in roues {
            guard let graine = graineIntacte(pour: roue) else { continue }
            let titreCible = tr(graine.titre)
            let optionsCibles = graine.options.map { tr($0) }
            let optionsActuelles = roue.optionsOrdonnees
            guard roue.titre != titreCible
                || optionsActuelles.map(\.label) != optionsCibles else { continue }
            roue.titre = titreCible
            for (option, label) in zip(optionsActuelles, optionsCibles) {
                option.label = label
            }
        }
    }

    /// La graine dont cette roue est la version intacte, s'il y en a une.
    private static func graineIntacte(pour roue: Roue) -> Graine? {
        let labels = roue.optionsOrdonnees.map(\.label)
        for graine in graines {
            guard graine.options.count == labels.count else { continue }
            for code in codesConnus {
                let titre = Langues.dans(code, graine.titre)
                let options = graine.options.map { Langues.dans(code, $0) }
                if roue.titre == titre && labels == options {
                    return graine
                }
            }
        }
        return nil
    }

    /// Titre de la roue affichée au tout premier lancement : la première
    /// expérience est un tirage, pas un formulaire.
    static var titrePremiereRoue: String { tr(graines[0].titre) }

    /// Crée une roue vierge prête à être éditée.
    static func nouvelleRoue(paletteParDefaut: Int) -> Roue {
        Roue(
            titre: "",
            options: [
                OptionRoue(label: "", ordre: 0),
                OptionRoue(label: "", ordre: 1)
            ],
            paletteID: paletteParDefaut
        )
    }
}
