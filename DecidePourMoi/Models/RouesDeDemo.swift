#if DEBUG
import Foundation
import SwiftData

/// Jeu de roues fixe pour les captures d'écran de la fiche App Store.
///
/// Piloté par l'argument de lancement `-captures.demo YES`, il remet le
/// même contenu à chaque lancement : les captures françaises et anglaises
/// montrent exactement les mêmes roues, dans le même ordre. Tout le fichier
/// est sous `#if DEBUG` : rien de tout cela n'existe dans le binaire publié.
enum RouesDeDemo {

    /// Rang de la roue « classe » dans la grille de « Mes roues ». Le
    /// parcours de captures la désigne par sa position, jamais par son
    /// titre, qui change avec la langue.
    static let rangDeLaClasse = 1

    static var demandees: Bool {
        UserDefaults.standard.bool(forKey: "captures.demo")
    }

    /// Les prénoms ne sont pas traduits : une liste de classe se colle
    /// telle quelle, quelle que soit la langue de l'interface.
    private static let eleves = ["Léa", "Marco", "Aïcha", "Tom", "Nina", "Sacha"]

    static func installer(dans contexte: ModelContext, roues: [Roue]) {
        for roue in roues { contexte.delete(roue) }
        RouesParDefaut.creer(dans: contexte)

        let classe = Roue(
            titre: tr("La classe"),
            options: eleves.enumerated().map { OptionRoue(label: $1, ordre: $0) },
            mode: .ordreDePassage,
            paletteID: 4
        )
        // Juste derrière la roue d'accueil dans la grille, jamais devant.
        classe.utiliseeLe = Date(timeIntervalSinceNow: -0.5)
        classe.creeeLe = classe.utiliseeLe
        classe.modifieeLe = classe.utiliseeLe
        contexte.insert(classe)

        try? contexte.save()
    }
}
#endif
