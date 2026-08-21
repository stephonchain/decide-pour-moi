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
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: fermer)

            if confettisActifs {
                Confettis(declencheur: compteur, couleurs: roue.palette.teintes)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }

            VStack(spacing: 26) {
                Text(intitule)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1.5)

                Text(label)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .lineLimit(4)
                    .padding(.horizontal, 24)
                    .scaleEffect(apparu ? 1 : 0.75)
                    .opacity(apparu ? 1 : 0)

                if roue.mode == .ordreDePassage {
                    Text(tr("Position \(roue.ordreDePassage.count) sur \(roue.optionsOrdonnees.count)"))
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                VStack(spacing: 12) {
                    Button(action: relancer) {
                        Label(tr("Relancer"), systemImage: "arrow.clockwise")
                            .boutonPrincipal()
                    }
                    .disabled(!roue.peutTourner)

                    if roue.mode == .avecRemise {
                        Button(action: retirer) {
                            HStack(spacing: 6) {
                                Label(tr("Retirer cette option"), systemImage: "minus.circle")
                                if !retraitAutorise { Cadenas() }
                            }
                            .boutonSecondaire()
                        }
                    }

                    Button(action: fermer) {
                        Text(tr("Fermer"))
                            .accessibilityIdentifier("bouton.fermerResultat")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                    }
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .padding(.vertical, 34)
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { apparu = true }
        }
    }

    private var intitule: String {
        switch roue.mode {
        case .avecRemise, .sansRemise: tr("Résultat")
        case .ordreDePassage: tr("Suivant")
        }
    }
}
