import Foundation
import SwiftUI

/// Annonce du résultat, en surimpression de la roue. Volontairement énorme :
/// c'est le moment que tout le monde regarde.
struct OverlayResultat: View {

    let label: String
    let roue: Roue
    let compteur: Int
    let confettisActifs: Bool
    let retraitAutorise: Bool
    let relancer: () -> Void
    let retirer: () -> Void
    let fermer: () -> Void

    @State private var apparu = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x0C0C28).opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: fermer)

            if confettisActifs {
                Confettis(declencheur: compteur, couleurs: roue.palette.teintes)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            // Une feuille posée en bas plutôt qu'un bloc au centre : la
            // roue reste visible derrière, et les actions tombent sous le
            // pouce.
            VStack(spacing: 22) {
                Surtitre(texte: intitule)

                HStack(spacing: 14) {
                    Circle()
                        .fill(couleurDuResultat)
                        .frame(width: 22, height: 22)
                    Text(label)
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(Encre.vive)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.4)
                        .lineLimit(3)
                }
                .scaleEffect(apparu ? 1 : 0.75)
                .opacity(apparu ? 1 : 0)

                if roue.mode == .ordreDePassage {
                    Text(tr("Position \(roue.ordreDePassage.count) sur \(roue.optionsOrdonnees.count)"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Encre.discrete)
                }

                VStack(spacing: 10) {
                    Button(action: relancer) {
                        Label(tr("Relancer"), systemImage: "arrow.clockwise")
                            .boutonPrincipal()
                    }
                    .disabled(!roue.peutTourner)
                    .opacity(roue.peutTourner ? 1 : 0.45)

                    HStack(spacing: 10) {
                        if roue.mode == .avecRemise {
                            Button(action: retirer) {
                                HStack(spacing: 6) {
                                    Text(tr("Retirer"))
                                    if !retraitAutorise { Cadenas() }
                                }
                                .boutonSecondaire()
                            }
                        }

                        Button(action: fermer) {
                            Text(tr("Fermer"))
                                .boutonSecondaire()
                        }
                        .accessibilityIdentifier("bouton.fermerResultat")
                    }
                }
            }
            .padding(.top, 30)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(Fond.carte, in: .rect(cornerRadius: 32))
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
            .offset(y: apparu ? 0 : 60)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { apparu = true }
        }
    }

    /// La pastille reprend la couleur du segment gagnant : le lien entre la
    /// roue et l'annonce se fait sans qu'on ait à l'expliquer.
    private var couleurDuResultat: Color {
        let options = roue.optionsOrdonnees
        guard let index = options.firstIndex(where: { $0.label == label }) else {
            return roue.palette.teintes.first ?? .accentColor
        }
        return roue.palette.couleur(index: index, total: options.count)
    }

    private var intitule: String {
        switch roue.mode {
        case .avecRemise, .sansRemise: tr("Résultat")
        case .ordreDePassage: tr("Suivant")
        }
    }
}
