import Foundation
import SwiftUI

/// Habillage commun : typographie arrondie, contrastes sur fond sombre.
extension View {

    /// Bouton circulaire discret de la barre du haut.
    func boutonRond() -> some View {
        self
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.white.opacity(0.12), in: .circle)
    }

    /// Bouton plein, pour l'action principale d'un écran.
    func boutonPrincipal() -> some View {
        self
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Fond.sombreProfond)
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .background(.white, in: .capsule)
    }

    /// Bouton secondaire, sur fond translucide.
    func boutonSecondaire() -> some View {
        self
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.white.opacity(0.12), in: .capsule)
    }

    func boutonSecondaireCompact() -> some View {
        self
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(.white.opacity(0.12), in: .circle)
    }

    /// Carte des feuilles modales.
    func carte() -> some View {
        self
            .padding(16)
            .background(Fond.carte, in: .rect(cornerRadius: 18))
    }
}

/// Feuille modale à l'identité de l'app : fond sombre, titre arrondi.
struct FeuilleSombre<Contenu: View>: View {
    let titre: LocalizedStringKey
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
                    Button(String(localized: "Terminé")) { fermer() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
