import SwiftData
import Foundation
import SwiftUI

/// Les 50 derniers tirages de la roue, horodatés et effaçables.
struct HistoriqueView: View {

    let roue: Roue

    @Environment(\.modelContext) private var contexte
    @State private var effacementDemande = false

    var body: some View {
        FeuilleSombre(titre: tr("Historique")) {
            Group {
                if roue.historiqueRecent.isEmpty {
                    ContentUnavailableView {
                        Label(tr("Aucun tirage"), systemImage: "clock")
                    } description: {
                        Text(tr("Les résultats de cette roue s'afficheront ici."))
                    }
                    .foregroundStyle(.white)
                } else {
                    List {
                        Section {
                            ForEach(roue.historiqueRecent) { tirage in
                                HStack {
                                    Text(tirage.label)
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                    Spacer()
                                    Text(tirage.date, format: .dateTime.day().month().hour().minute())
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .listRowBackground(Fond.carte)
                            }
                        } footer: {
                            Text(tr("Les 50 derniers tirages sont conservés sur l'appareil."))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Section {
                            Button(role: .destructive) {
                                effacementDemande = true
                            } label: {
                                Label(tr("Effacer l'historique"), systemImage: "trash")
                            }
                            .listRowBackground(Fond.carte)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                }
            }
        }
        .confirmationDialog(
            Text(tr("Effacer l'historique ?")),
            isPresented: $effacementDemande,
            titleVisibility: .visible
        ) {
            Button(tr("Effacer"), role: .destructive) { effacer() }
            Button(tr("Annuler"), role: .cancel) {}
        }
    }

    private func effacer() {
        for tirage in roue.historique ?? [] {
            contexte.delete(tirage)
        }
        roue.historique = []
        Haptiques.shared.succes()
    }
}
