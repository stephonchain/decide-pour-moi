import Foundation
import SwiftData

/// Roues installées au premier lancement. Elles sont ensuite modifiables et
/// supprimables comme n'importe quelle roue créée par l'utilisateur.
enum RouesParDefaut {

    /// Titre de la roue affichée au tout premier lancement : la première
    /// expérience est un tirage, pas un formulaire.
    static let titrePremiereRoue = tr("Ce soir on mange…")

    static func creer(dans contexte: ModelContext) {
        let modeles: [(String, [String], Int)] = [
            (
                titrePremiereRoue,
                [
                    tr("Pizza"),
                    tr("Sushis"),
                    tr("Burger"),
                    tr("Pâtes"),
                    tr("Salade"),
                    tr("Restes du frigo")
                ],
                0
            ),
            (
                tr("Oui / Non"),
                [tr("Oui"), tr("Non")],
                2
            ),
            (
                tr("Pile ou face"),
                [tr("Pile"), tr("Face")],
                5
            ),
            (
                tr("Chiffres 1 à 10"),
                (1...10).map { String($0) },
                1
            ),
            (
                tr("Qui commence ?"),
                (1...4).map { tr("Joueur \($0)") },
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
