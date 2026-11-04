import Foundation
import SwiftUI

/// Habillage commun : typographie arrondie, contrastes sur fond nuit.
///
/// La direction « Soirée confettis » tient en quatre gestes : le fond est
/// la nuit de l'icône, le jaune ne sert qu'à agir, les couleurs de la roue
/// ne servent qu'au jeu, et tout ce qui se tape fait au moins 44 points.
extension View {

    /// Bouton circulaire discret, posé à même la nuit.
    func boutonRond() -> some View {
        self
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Encre.vive)
            .frame(width: 44, height: 44)
            .background(.white.opacity(0.08), in: .circle)
    }

    /// Bouton de la barre du haut : une carte carrée, pas un rond. Il doit
    /// se lire comme un élément d'interface, pas comme une pastille.
    func boutonCarte() -> some View {
        self
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Encre.vive)
            .frame(width: 44, height: 44)
            .background(Fond.carte, in: .rect(cornerRadius: 14))
    }

    /// L'action principale d'un écran, et la seule tache de jaune.
    func boutonPrincipal() -> some View {
        self
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(Fond.sombre)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Accent.soleil, in: .capsule)
    }

    /// L'action d'à côté : même largeur, même gabarit, sans le jaune.
    func boutonSecondaire() -> some View {
        self
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(Encre.vive)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Fond.carteChoisie, in: .capsule)
    }

    /// Les deux raccourcis sous la roue : plus bas, moins ronds, plus
    /// discrets que l'action principale qui les surplombe.
    func boutonBarre() -> some View {
        self
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(Encre.vive)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Fond.carte, in: .rect(cornerRadius: 16))
    }

    func boutonSecondaireCompact() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Encre.vive)
            .frame(width: 44, height: 44)
            .background(Fond.carte, in: .rect(cornerRadius: 14))
    }

    /// Carte des feuilles modales.
    func carte() -> some View {
        self
            .padding(16)
            .background(Fond.carte, in: .rect(cornerRadius: 22))
    }
}

/// Surtitre : la ligne en capitales jaunes qui annonce la page. Courte,
/// sinon elle vole la vedette au titre qu'elle introduit.
struct Surtitre: View {
    /// Texte déjà traduit, via `tr(_:)`.
    let texte: String

    var body: some View {
        Text(texte)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Accent.soleil)
    }
}

/// Titre de page : le même corps partout, pour que les pages s'enchaînent
/// sans ressaut.
struct TitrePage: View {
    let texte: String
    var centre = false

    var body: some View {
        Text(texte)
            .font(.system(size: 29, weight: .black, design: .rounded))
            .foregroundStyle(Encre.vive)
            .multilineTextAlignment(centre ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: centre ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Texte courant d'une page : l'encre douce, jamais le blanc pur, qui
/// vibre sur un fond aussi sombre.
struct TextePage: View {
    let texte: String
    var centre = false

    var body: some View {
        Text(texte)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Encre.douce)
            .lineSpacing(3)
            .multilineTextAlignment(centre ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: centre ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Progression de l'onboarding, en segments plutôt qu'en barre continue :
/// chaque étape franchie prend une couleur de la roue, si bien que la
/// progression raconte déjà ce que l'app fait.
struct ProgressionSegmentee: View {
    /// Page courante, à partir de 1.
    let page: Int
    let total: Int

    private var teintes: [Color] { Palette.toutes[0].teintes }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < page ? teintes[index % teintes.count] : Color.white.opacity(0.14))
                    .frame(height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: page)
        .accessibilityElement()
        .accessibilityLabel(Text(tr("Étape \(page) sur \(total)")))
    }
}

/// Marque « premium » : un verrou se montre, il ne se cache pas. Annoncer
/// ce qui est payant avant le tap vaut mieux qu'un paywall en embuscade.
struct BadgePremium: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .black))
            Text(tr("Mode premium"))
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.2)
                .textCase(.uppercase)
        }
        .foregroundStyle(Accent.soleil)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(Accent.voile, in: .rect(cornerRadius: 12))
    }
}

/// Pastille de sélection d'une option : cercle vide au repos, disque jaune
/// coché une fois choisi.
struct PastilleChoix: View {
    let choisie: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(choisie ? Accent.soleil : Color.white.opacity(0.3), lineWidth: 2)
            if choisie {
                Circle().fill(Accent.soleil)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Fond.sombre)
            }
        }
        .frame(width: 26, height: 26)
        .animation(.easeInOut(duration: 0.15), value: choisie)
    }
}

/// Une option de l'onboarding : puce colorée, libellé, pastille. Le même
/// gabarit sert aux questions à choix unique et aux choix multiples —
/// c'est ce qui fait tenir les quinze pages ensemble.
struct CarteChoix<Puce: View>: View {
    let libelle: String
    let choisie: Bool
    @ViewBuilder var puce: Puce
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                puce
                    .frame(width: 40, height: 40)
                Text(libelle)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Encre.vive)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                PastilleChoix(choisie: choisie)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(choisie ? Fond.carteChoisie : Fond.carte, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(choisie ? Accent.soleil : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: choisie)
    }
}

/// Puce carrée colorée d'une option : une couleur de la roue, et dedans
/// soit un symbole, soit rien.
struct PuceOption: View {
    let couleur: Color
    var symbole: String? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(couleur)
            .overlay {
                if let symbole {
                    Image(systemName: symbole)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Fond.sombre)
                }
            }
    }
}

/// Feuille modale à l'identité de l'app : fond nuit, titre arrondi.
struct FeuilleSombre<Contenu: View>: View {
    /// Titre déjà traduit, via `tr(_:)`.
    let titre: String
    @ViewBuilder var contenu: Contenu

    @Environment(\.dismiss) private var fermer

    var body: some View {
        NavigationStack {
            ZStack {
                FondApplication()
                contenu
            }
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Fond.sombre, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Terminé")) { fermer() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
