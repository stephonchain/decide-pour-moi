import Foundation
import SwiftData

/// Roues installées au premier lancement. Elles sont ensuite modifiables et
/// supprimables comme n'importe quelle roue créée par l'utilisateur.
enum RouesParDefaut {

    /// Titre de la roue affichée au tout premier lancement : la première
    /// expérience est un tirage, pas un formulaire.
    static let titrePremiereRoue = String(localized: "Ce soir on mange…")

    static func creer(dans contexte: ModelContext) {
        let modeles: [(String, [String], Int)] = [
            (
                titrePremiereRoue,
                [
                    String(localized: "Pizza"),
                    String(localized: "Sushis"),
                    String(localized: "Burger"),
                    String(localized: "Pâtes"),
                    String(localized: "Salade"),
                    String(localized: "Restes du frigo")
                ],
                0
            ),
            (
                String(localized: "Oui / Non"),
                [String(localized: "Oui"), String(localized: "Non")],
                2
            ),
            (
                String(localized: "Pile ou face"),
                [String(localized: "Pile"), String(localized: "Face")],
                5
            ),
            (
                String(localized: "Chiffres 1 à 10"),
                (1...10).map { String($0) },
                1
            ),
            (
                String(localized: "Qui commence ?"),
                (1...4).map { String(localized: "Joueur \($0)") },
                3
            )
        ]

        for (index, modele) in modeles.enumerated() {
            let (titre, libelles, palette) = modele
            let options = libelles.enumerated().map { OptionRoue(label: $0.element, ordre: $0.offset) }
            let roue = Roue(titre: titre, options: options, paletteID: palette)
            // La première roue de la liste doit être celle qui s'ouvre au lancement.
            roue.utiliseeLe = Date(timeIntervalSinceNow: -Double(index))
            roue.creeeLe = roue.utiliseeLe
            contexte.insert(roue)
        }
    }

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
