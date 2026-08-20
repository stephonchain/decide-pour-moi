import SwiftData
import Foundation
import SwiftUI

/// Racine de l'app : installe les roues du premier lancement puis affiche
/// directement la dernière roue utilisée. Aucun écran d'accueil, aucun tunnel.
struct RacineView: View {

    @Environment(\.modelContext) private var contexte
    @Query(sort: \Roue.utiliseeLe, order: .reverse) private var roues: [Roue]

    @State private var amorcageTente = false

    private var roueCourante: Roue? { roues.first }

    var body: some View {
        ZStack {
            FondApplication()

            if let roue = roueCourante {
                EcranRoue(roue: roue)
                    .id(roue.id)
                    .transition(.opacity)
            } else if amorcageTente {
                AucuneRoueView { creerUneRoueDeSecours() }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: roueCourante?.id)
        .task { amorcer() }
    }

    private func amorcer() {
        guard !amorcageTente else { return }
        amorcageTente = true
        guard roues.isEmpty, !Reglages.amorcageFait else { return }
        RouesParDefaut.creer(dans: contexte)
        try? contexte.save()
        Reglages.amorcageFait = true
    }

    private func creerUneRoueDeSecours() {
        RouesParDefaut.creer(dans: contexte)
        try? contexte.save()
    }
}

struct AucuneRoueView: View {
    let restaurer: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 54))
                .foregroundStyle(.white.opacity(0.8))
            Text("Aucune roue")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Remettez les roues de départ pour recommencer.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button(action: restaurer) {
                Label("Restaurer les roues de départ", systemImage: "arrow.counterclockwise")
                    .boutonPrincipal()
            }
        }
        .padding(30)
    }
}
