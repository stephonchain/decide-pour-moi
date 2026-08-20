import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Palette de couleurs d'une roue. Six jeux harmonieux, pas de sélecteur
/// couleur par option : ce serait du bruit pour un gain nul.
struct Palette: Identifiable {
    let id: Int
    let nomCle: String.LocalizationValue
    let teintes: [Color]

    var nom: String { tr(nomCle) }

    /// Couleur du segment `index`, en évitant que le premier et le dernier
    /// segment soient identiques quand le nombre d'options est un multiple
    /// de la taille de la palette.
    func couleur(index: Int, total: Int) -> Color {
        guard !teintes.isEmpty else { return .accentColor }
        guard total > teintes.count else { return teintes[index % teintes.count] }
        let collision = total % teintes.count == 1 && index == total - 1
        return teintes[(index + (collision ? 1 : 0)) % teintes.count]
    }

    static let toutes: [Palette] = [
        Palette(
            id: 0,
            nomCle: "Fête",
            teintes: [
                Color(hex: 0xFF5A5F), Color(hex: 0xFFA23A), Color(hex: 0xFFD53E),
                Color(hex: 0x4BC46B), Color(hex: 0x22BFCB), Color(hex: 0x3A9BF0),
                Color(hex: 0x8B5CF6), Color(hex: 0xF2609B)
            ]
        ),
        Palette(
            id: 1,
            nomCle: "Agrumes",
            teintes: [
                Color(hex: 0xFF6B35), Color(hex: 0xFFB627), Color(hex: 0xF9E04B),
                Color(hex: 0xE84855), Color(hex: 0xFF8C42), Color(hex: 0xD64550)
            ]
        ),
        Palette(
            id: 2,
            nomCle: "Lagon",
            teintes: [
                Color(hex: 0x1B9AAA), Color(hex: 0x3FC1C9), Color(hex: 0x4A90D9),
                Color(hex: 0x5C6BC0), Color(hex: 0x36C9A0), Color(hex: 0x7AD9E8)
            ]
        ),
        Palette(
            id: 3,
            nomCle: "Crépuscule",
            teintes: [
                Color(hex: 0x6A4C93), Color(hex: 0x9163CB), Color(hex: 0xC86FC9),
                Color(hex: 0xEE6C8A), Color(hex: 0xF79D65), Color(hex: 0x4E4187)
            ]
        ),
        Palette(
            id: 4,
            nomCle: "Forêt",
            teintes: [
                Color(hex: 0x2D6A4F), Color(hex: 0x40916C), Color(hex: 0x74C69D),
                Color(hex: 0x95D5B2), Color(hex: 0xB7791F), Color(hex: 0x588157)
            ]
        ),
        Palette(
            id: 5,
            nomCle: "Encre",
            teintes: [
                Color(hex: 0x2E3D6B), Color(hex: 0x455A94), Color(hex: 0x6C7BBB),
                Color(hex: 0x8C6FAF), Color(hex: 0x3F5E8C), Color(hex: 0x5B4E8C)
            ]
        )
    ]

    static func palette(id: Int) -> Palette {
        toutes.first { $0.id == id } ?? toutes[0]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Luminance perçue, pour poser un libellé blanc ou sombre sur le segment.
    var estClaire: Bool {
        #if canImport(UIKit)
        var rouge: CGFloat = 0, vert: CGFloat = 0, bleu: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&rouge, green: &vert, blue: &bleu, alpha: &alpha) else { return false }
        return 0.299 * rouge + 0.587 * vert + 0.114 * bleu > 0.62
        #else
        return false
        #endif
    }
}

/// Fond de l'app : l'indigo profond de l'icône, la roue reste la star.
enum Fond {
    static let sombre = Color(hex: 0x1E1E3C)
    static let sombreProfond = Color(hex: 0x14142B)
    static let carte = Color(hex: 0x2A2A50)
}
