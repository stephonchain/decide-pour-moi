import SwiftData
import Foundation
import SwiftUI

/// Création et édition d'une roue. Le collage multi-lignes passe par la
/// feuille « Liste texte » : une ligne = une option.
struct EditionRoueView: View {

    @Bindable var roue: Roue
    let estUneCreation: Bool
    var apresCreation: ((Roue) -> Void)? = nil

    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var fermer

    @State private var listeTexteAffichee = false

    private var optionsValides: [OptionRoue] {
        roue.optionsOrdonnees.filter { !$0.label.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var enregistrementPossible: Bool { optionsValides.count >= 2 }

    var body: some View {
        NavigationStack {
            ZStack {
                FondApplication()
                formulaire
            }
            .navigationTitle(estUneCreation ? Text(tr("Nouvelle roue")) : Text(tr("Modifier")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Fond.sombre, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if estUneCreation {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(tr("Annuler")) { annuler() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(estUneCreation ? tr("Créer") : tr("Terminé")) {
                        enregistrer()
                    }
                    .fontWeight(.semibold)
                    .disabled(!enregistrementPossible)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $listeTexteAffichee) {
            ListeTexteView(texte: roue.optionsOrdonnees.map(\.label).joined(separator: "\n")) { lignes in
                roue.remplacerOptions(par: lignes)
                listeTexteAffichee = false
            }
        }
    }

    private var formulaire: some View {
        List {
            Section {
                TextField(tr("Titre de la roue"), text: $roue.titre)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .listRowBackground(Fond.carte)
            }

            Section {
                ForEach(roue.optionsOrdonnees) { option in
                    LigneOption(option: option)
                        .listRowBackground(Fond.carte)
                }
                .onMove(perform: deplacer)
                .onDelete(perform: supprimerIndices)

                Button {
                    ajouterUneOption()
                } label: {
                    Label(tr("Ajouter une option"), systemImage: "plus.circle.fill")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .listRowBackground(Fond.carte)

                Button {
                    listeTexteAffichee = true
                } label: {
                    Label(tr("Coller ou modifier la liste"), systemImage: "doc.on.clipboard")
                        .font(.system(.body, design: .rounded))
                }
                .listRowBackground(Fond.carte)
            } header: {
                Text(tr("Options"))
            } footer: {
                Text(trRiche("Le poids multiplie la taille de la part **et** ses chances de sortir."))
            }

            Section {
                ForEach(ModeTirage.allCases) { mode in
                    Button {
                        roue.mode = mode
                        Haptiques.shared.selection()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.symbole)
                                .frame(width: 26)
                                .foregroundStyle(.white.opacity(0.8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.titre)
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                Text(mode.explication)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            if roue.mode == mode {
                                Image(systemName: "checkmark")
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .listRowBackground(Fond.carte)
                }
            } header: {
                Text(tr("Mode de tirage"))
            }

            Section {
                ChoixDePalette(paletteID: $roue.paletteID)
                    .listRowBackground(Fond.carte)
            } header: {
                Text(tr("Couleurs"))
            }
        }
        .scrollContentBackground(.hidden)
        .foregroundStyle(.white)
        .tint(.white)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: Actions

    private func ajouterUneOption() {
        let option = OptionRoue(label: "", ordre: roue.optionsOrdonnees.count)
        roue.options = roue.optionsOrdonnees + [option]
    }

    private func supprimer(_ option: OptionRoue) {
        roue.options?.removeAll { $0.id == option.id }
        contexte.delete(option)
        roue.renumeroter()
    }

    private func supprimerIndices(_ indices: IndexSet) {
        let aSupprimer = indices.map { roue.optionsOrdonnees[$0] }
        for option in aSupprimer { supprimer(option) }
    }

    private func deplacer(_ source: IndexSet, _ destination: Int) {
        var options = roue.optionsOrdonnees
        options.move(fromOffsets: source, toOffset: destination)
        for (index, option) in options.enumerated() { option.ordre = index }
        roue.modifieeLe = .now
    }

    private func enregistrer() {
        // On jette les lignes vides restées dans le formulaire.
        for option in roue.optionsOrdonnees where option.label.trimmingCharacters(in: .whitespaces).isEmpty {
            supprimer(option)
        }
        for option in roue.optionsOrdonnees {
            option.label = option.label.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if roue.titre.trimmingCharacters(in: .whitespaces).isEmpty {
            roue.titre = tr("Nouvelle roue")
        }
        roue.renumeroter()
        roue.modifieeLe = .now
        roue.utiliseeLe = .now
        try? contexte.save()
        Haptiques.shared.succes()
        if estUneCreation { apresCreation?(roue) }
        fermer()
    }

    /// Uniquement à la création : la roue n'a jamais existé pour l'utilisateur,
    /// on la retire purement et simplement.
    private func annuler() {
        contexte.delete(roue)
        fermer()
    }
}

/// Une ligne du formulaire : le libellé et son poids.
struct LigneOption: View {

    @Bindable var option: OptionRoue

    var body: some View {
        HStack(spacing: 10) {
            TextField(tr("Option"), text: $option.label)
                .font(.system(.body, design: .rounded))
                .submitLabel(.next)

            Menu {
                Picker(tr("Poids"), selection: $option.poids) {
                    ForEach(1...3, id: \.self) { poids in
                        Text(verbatim: "×\(poids)").tag(poids)
                    }
                }
            } label: {
                Text(verbatim: "×\(option.poidsValide)")
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(option.poidsValide > 1 ? Fond.sombreProfond : .white.opacity(0.7))
                    .frame(width: 34, height: 26)
                    .background(
                        option.poidsValide > 1 ? Color.white : Color.white.opacity(0.12),
                        in: .capsule
                    )
            }
            .accessibilityLabel(Text(tr("Poids de l'option")))
        }
    }
}

/// Sélecteur de palette : on montre les couleurs, pas leur nom.
struct ChoixDePalette: View {

    @Binding var paletteID: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Palette.toutes) { palette in
                Button {
                    paletteID = palette.id
                    Haptiques.shared.selection()
                } label: {
                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            ForEach(Array(palette.teintes.prefix(6).enumerated()), id: \.offset) { _, teinte in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(teinte)
                                    .frame(width: 20, height: 22)
                            }
                        }
                        Text(palette.nom)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                        Spacer()
                        if paletteID == palette.id {
                            Image(systemName: "checkmark")
                                .fontWeight(.bold)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
