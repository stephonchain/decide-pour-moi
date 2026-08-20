import Foundation
import SwiftUI

/// Édition de la liste en texte brut : une ligne = une option.
/// C'est le chemin le plus court pour coller une liste d'élèves ou d'invités.
struct ListeTexteView: View {

    @State private var texte: String
    let valider: ([String]) -> Void

    @Environment(\.dismiss) private var fermer
    @FocusState private var champActif: Bool

    init(texte: String, valider: @escaping ([String]) -> Void) {
        _texte = State(initialValue: texte)
        self.valider = valider
    }

    private var lignes: [String] {
        texte
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FondApplication()
                VStack(alignment: .leading, spacing: 10) {
                    Text(tr("Une ligne = une option. Collez votre liste, tout est créé d'un coup."))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))

                    TextEditor(text: $texte)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .background(Fond.carte, in: .rect(cornerRadius: 16))
                        .focused($champActif)

                    Text(tr("\(lignes.count) options"))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(16)
            }
            .navigationTitle(Text(tr("Liste des options")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Fond.sombre, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { fermer() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Valider")) { valider(lignes) }
                        .fontWeight(.semibold)
                        .disabled(lignes.count < 2)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { champActif = true }
    }
}

/// Création d'une roue directement depuis une liste collée.
struct ImportListeView: View {

    let creer: (String, [String]) -> Void

    @State private var titre = ""
    @State private var texte = ""
    @Environment(\.dismiss) private var fermer

    private var lignes: [String] {
        texte
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FondApplication()
                VStack(alignment: .leading, spacing: 12) {
                    TextField(tr("Titre de la roue"), text: $titre)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Fond.carte, in: .rect(cornerRadius: 14))

                    Text(tr("Une ligne = une option."))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))

                    TextEditor(text: $texte)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .background(Fond.carte, in: .rect(cornerRadius: 16))

                    Text(tr("\(lignes.count) options"))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(16)
            }
            .navigationTitle(Text(tr("Coller une liste")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Fond.sombre, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { fermer() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Créer")) {
                        creer(titre.trimmingCharacters(in: .whitespaces), lignes)
                    }
                    .fontWeight(.semibold)
                    .disabled(lignes.count < 2)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
