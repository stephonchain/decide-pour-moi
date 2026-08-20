import Foundation
import SwiftUI

/// Bandeau visible sous la roue en mode « ordre de passage » : la liste se
/// construit sous les yeux de tout le monde.
struct BandeauOrdreDePassage: View {

    let roue: Roue
    let reinitialiser: () -> Void

    @State private var listeAffichee = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ordre de passage")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                Spacer()
                Button {
                    listeAffichee = true
                } label: {
                    Text("Voir tout")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(roue.ordreDePassage.enumerated()), id: \.element.id) { position, tirage in
                        HStack(spacing: 6) {
                            Text(verbatim: "\(position + 1)")
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                                .foregroundStyle(.white.opacity(0.55))
                            Text(tirage.label)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.1), in: .capsule)
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollClipDisabled()
        }
        .padding(14)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
        .sheet(isPresented: $listeAffichee) {
            ListeOrdreDePassage(roue: roue, reinitialiser: reinitialiser)
        }
    }
}

struct ListeOrdreDePassage: View {

    let roue: Roue
    let reinitialiser: () -> Void

    @Environment(\.dismiss) private var fermer

    var body: some View {
        FeuilleSombre(titre: "Ordre de passage") {
            List {
                Section {
                    ForEach(Array(roue.ordreDePassage.enumerated()), id: \.element.id) { position, tirage in
                        HStack(spacing: 14) {
                            Text(verbatim: "\(position + 1)")
                                .font(.system(.body, design: .monospaced, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(width: 34, alignment: .trailing)
                            Text(tirage.label)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .listRowBackground(Fond.carte)
                    }
                } footer: {
                    Text("\(roue.optionsActives.count) options encore en jeu.")
                        .foregroundStyle(.white.opacity(0.5))
                }

                Section {
                    ShareLink(item: roue.texteOrdreDePassage) {
                        Label("Partager la liste", systemImage: "square.and.arrow.up")
                    }
                    .listRowBackground(Fond.carte)

                    Button(role: .destructive) {
                        reinitialiser()
                        fermer()
                    } label: {
                        Label("Recommencer un ordre", systemImage: "arrow.counterclockwise")
                    }
                    .listRowBackground(Fond.carte)
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(.white)
        }
    }
}
