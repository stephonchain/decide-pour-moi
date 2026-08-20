import Foundation
import SwiftData

/// Mode de tirage, réglé roue par roue.
enum ModeTirage: String, Codable, CaseIterable, Identifiable, Sendable {
    /// L'option tirée reste dans la roue.
    case avecRemise
    /// L'option tirée sort de la roue jusqu'à réinitialisation.
    case sansRemise
    /// Enchaîne les tirages sans remise et produit une liste ordonnée.
    case ordreDePassage

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .avecRemise: String(localized: "Avec remise")
        case .sansRemise: String(localized: "Sans remise")
        case .ordreDePassage: String(localized: "Ordre de passage")
        }
    }

    var explication: String {
        switch self {
        case .avecRemise: String(localized: "L'option tirée reste dans la roue.")
        case .sansRemise: String(localized: "L'option tirée sort de la roue jusqu'à réinitialisation.")
        case .ordreDePassage: String(localized: "Les tirages s'enchaînent sans remise et forment une liste ordonnée.")
        }
    }

    var symbole: String {
        switch self {
        case .avecRemise: "arrow.trianglehead.2.clockwise.rotate.90"
        case .sansRemise: "minus.circle"
        case .ordreDePassage: "list.number"
        }
    }

    /// Les deux modes qui retirent l'option tirée.
    var retireLOptionTiree: Bool { self != .avecRemise }
}

@Model
final class Roue {
    var id: UUID = UUID()
    var titre: String = ""
    var modeBrut: String = ModeTirage.avecRemise.rawValue
    var paletteID: Int = 0
    var creeeLe: Date = Date()
    var modifieeLe: Date = Date()
    /// Dernière ouverture, pour rouvrir la roue utilisée en dernier.
    var utiliseeLe: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \OptionRoue.roue)
    var options: [OptionRoue]? = []

    @Relationship(deleteRule: .cascade, inverse: \Tirage.roue)
    var historique: [Tirage]? = []

    init(titre: String, options: [OptionRoue] = [], mode: ModeTirage = .avecRemise, paletteID: Int = 0) {
        self.id = UUID()
        self.titre = titre
        self.modeBrut = mode.rawValue
        self.paletteID = paletteID
        self.creeeLe = .now
        self.modifieeLe = .now
        self.utiliseeLe = .now
        self.options = options
        self.historique = []
        for (index, option) in options.enumerated() {
            option.ordre = index
        }
    }

    var mode: ModeTirage {
        get { ModeTirage(rawValue: modeBrut) ?? .avecRemise }
        set { modeBrut = newValue.rawValue }
    }

    /// Toutes les options, dans l'ordre d'affichage.
    var optionsOrdonnees: [OptionRoue] {
        (options ?? []).sorted { $0.ordre < $1.ordre }
    }

    /// Les options réellement présentes sur la roue (hors options déjà sorties).
    var optionsActives: [OptionRoue] {
        mode.retireLOptionTiree ? optionsOrdonnees.filter { !$0.retiree } : optionsOrdonnees
    }

    /// Historique du plus récent au plus ancien.
    var historiqueRecent: [Tirage] {
        (historique ?? []).sorted { $0.date > $1.date }
    }

    /// Résultats du mode « ordre de passage », dans l'ordre de tirage.
    var ordreDePassage: [Tirage] {
        (historique ?? []).filter { $0.faitPartieDeLOrdre }.sorted { $0.date < $1.date }
    }

    var palette: Palette { Palette.palette(id: paletteID) }

    /// Une seule option restante suffit : c'est ainsi qu'on termine un
    /// ordre de passage ou un tirage sans remise.
    var peutTourner: Bool { !optionsActives.isEmpty }

    var estEpuisee: Bool { mode.retireLOptionTiree && optionsActives.isEmpty }

    var resume: String {
        let total = optionsOrdonnees.count
        if mode.retireLOptionTiree {
            return String(localized: "\(optionsActives.count) sur \(total) restantes")
        }
        return String(localized: "\(total) options")
    }

    // MARK: Édition

    func remplacerOptions(par libelles: [String]) {
        let anciennes = optionsOrdonnees
        var reutilisables = anciennes
        var nouvelles: [OptionRoue] = []
        for (index, libelle) in libelles.enumerated() {
            if let position = reutilisables.firstIndex(where: { $0.label == libelle }) {
                let option = reutilisables.remove(at: position)
                option.ordre = index
                nouvelles.append(option)
            } else {
                nouvelles.append(OptionRoue(label: libelle, ordre: index))
            }
        }
        options = nouvelles
        modifieeLe = .now
    }

    func renumeroter() {
        for (index, option) in optionsOrdonnees.enumerated() {
            option.ordre = index
        }
    }

    /// Remet toutes les options en jeu et vide l'ordre de passage en cours.
    func reinitialiserTirages() {
        for option in optionsOrdonnees {
            option.retiree = false
        }
        for tirage in historique ?? [] {
            tirage.faitPartieDeLOrdre = false
        }
        modifieeLe = .now
    }

    /// Texte de partage : titre puis une option par ligne.
    var texteDePartage: String {
        ([titre] + optionsOrdonnees.map(\.label)).joined(separator: "\n")
    }

    /// Texte de partage de l'ordre de passage : « 1. Nom ».
    var texteOrdreDePassage: String {
        let lignes = ordreDePassage.enumerated().map { "\($0.offset + 1). \($0.element.label)" }
        return ([titre] + lignes).joined(separator: "\n")
    }

    /// Vue moteur de la roue : uniquement les options en jeu.
    var optionsMoteur: [SpinOption] {
        optionsActives.map { SpinOption(id: $0.id, poids: $0.poids) }
    }
}

@Model
final class OptionRoue {
    var id: UUID = UUID()
    var label: String = ""
    /// 1, 2 ou 3. Multiplie la part angulaire *et* la probabilité.
    var poids: Int = 1
    /// Vraie quand l'option est sortie de la roue (modes sans remise).
    var retiree: Bool = false
    var ordre: Int = 0
    var roue: Roue?

    init(label: String, poids: Int = 1, ordre: Int = 0) {
        self.id = UUID()
        self.label = label
        self.poids = min(max(poids, 1), 3)
        self.retiree = false
        self.ordre = ordre
    }

    var poidsValide: Int { min(max(poids, 1), 3) }
}

@Model
final class Tirage {
    var id: UUID = UUID()
    /// Libellé figé au moment du tirage : l'historique reste lisible même
    /// si l'option est renommée ou supprimée ensuite.
    var label: String = ""
    var date: Date = Date()
    /// Vrai quand ce tirage appartient à l'ordre de passage en cours.
    var faitPartieDeLOrdre: Bool = false
    var roue: Roue?

    init(label: String, date: Date = .now, faitPartieDeLOrdre: Bool = false) {
        self.id = UUID()
        self.label = label
        self.date = date
        self.faitPartieDeLOrdre = faitPartieDeLOrdre
    }
}
