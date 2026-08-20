import SwiftData
import Foundation
import SwiftUI

/// Grille des roues sauvegardées, plus le bouton de création et l'encart
/// pour nos autres apps.
struct MesRouesView: View {

    let roueCourante: Roue
    let ouvrir: (Roue) -> Void

    @Environment(\.modelContext) private var contexte
    @Environment(\.dismiss) private var fermer
    @Query(sort: \Roue.utiliseeLe, order: .reverse) private var roues: [Roue]

    @State private var roueEnCreation: Roue? = nil
    @State private var roueAsupprimer: Roue? = nil
    @State private var importAffiche = false
    @State private var premium = PremiumManager.shared
    @State private var contextePaywall: ContextePaywall? = nil

    private let colonnes = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        FeuilleSombre(titre: tr("Mes roues")) {
            ScrollView {
                LazyVGrid(columns: colonnes, spacing: 14) {
                    BoutonNouvelleRoue { creer() }

                    ForEach(roues) { roue in
                        let ouvrable = premium.acces.peutOuvrir(roue)
                        VignetteRoue(roue: roue, estCourante: roue.id == roueCourante.id, verrouillee: !ouvrable)
                            .onTapGesture {
                                if ouvrable {
                                    Haptiques.shared.selection()
                                    ouvrir(roue)
                                } else {
                                    presenterPaywall(.roueVerrouillee)
                                }
                            }
                            .contextMenu {
                                if ouvrable {
                                    Button {
                                        dupliquer(roue)
                                    } label: {
                                        Label(tr("Dupliquer"), systemImage: "plus.square.on.square")
                                    }
                                    ShareLink(item: roue.texteDePartage) {
                                        Label(tr("Partager"), systemImage: "square.and.arrow.up")
                                    }
                                }
                                Button(role: .destructive) {
                                    roueAsupprimer = roue
                                } label: {
                                    Label(tr("Supprimer"), systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Button {
                    if peutCreer {
                        importAffiche = true
                    } else {
                        presenterPaywall(.creationDeRoue)
                    }
                } label: {
                    Label(tr("Coller une liste pour créer une roue"), systemImage: "doc.on.clipboard")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                EncartPromo()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
            }
        }
        .sheet(item: $contextePaywall) { contexte in
            PaywallAdapte(contexte: contexte)
        }
        .sheet(item: $roueEnCreation) { roue in
            EditionRoueView(roue: roue, estUneCreation: true) { creee in
                ouvrir(creee)
            }
        }
        .sheet(isPresented: $importAffiche) {
            ImportListeView { titre, libelles in
                importer(titre: titre, libelles: libelles)
            }
        }
        .confirmationDialog(
            Text(tr("Supprimer cette roue ?")),
            isPresented: .init(get: { roueAsupprimer != nil }, set: { if !$0 { roueAsupprimer = nil } }),
            titleVisibility: .visible
        ) {
            Button(tr("Supprimer"), role: .destructive) {
                if let roueAsupprimer { supprimer(roueAsupprimer) }
                roueAsupprimer = nil
            }
            Button(tr("Annuler"), role: .cancel) { roueAsupprimer = nil }
        } message: {
            Text(tr("Ses options et son historique seront effacés."))
        }
    }

    // MARK: Accès

    /// Seules les roues déverrouillées comptent contre la limite gratuite :
    /// les teasers préinstallés n'ont jamais été à l'utilisateur.
    private var peutCreer: Bool {
        premium.acces.peutCreerRoue(rouesDeverrouillees: roues.filter { !$0.verrouillee }.count)
    }

    /// L'utilisateur historique découvre le passage en freemium par le
    /// message « Décide pour moi évolue », une seule fois.
    private func presenterPaywall(_ contexte: ContextePaywall) {
        if Reglages.utilisateurHistorique && !Reglages.evolutionAnnoncee {
            Reglages.evolutionAnnoncee = true
            contextePaywall = .evolution
        } else {
            contextePaywall = contexte
        }
    }

    // MARK: Actions

    private func creer() {
        guard peutCreer else {
            presenterPaywall(.creationDeRoue)
            return
        }
        Haptiques.shared.selection()
        let roue = RouesParDefaut.nouvelleRoue(paletteParDefaut: Reglages.paletteParDefaut)
        contexte.insert(roue)
        roueEnCreation = roue
    }

    private func dupliquer(_ roue: Roue) {
        guard peutCreer else {
            presenterPaywall(.creationDeRoue)
            return
        }
        let copie = Roue(
            titre: tr("\(roue.titre) (copie)"),
            options: roue.optionsOrdonnees.enumerated().map {
                OptionRoue(label: $0.element.label, poids: $0.element.poidsValide, ordre: $0.offset)
            },
            mode: roue.mode,
            paletteID: roue.paletteID
        )
        contexte.insert(copie)
        Haptiques.shared.succes()
    }

    private func supprimer(_ roue: Roue) {
        // Si c'est la roue affichée qui part, on bascule sur la suivante.
        if roue.id == roueCourante.id, let remplacante = roues.first(where: { $0.id != roue.id }) {
            ouvrir(remplacante)
        }
        contexte.delete(roue)
        Haptiques.shared.succes()
    }

    private func importer(titre: String, libelles: [String]) {
        guard !libelles.isEmpty, peutCreer else { return }
        let roue = Roue(
            titre: titre.isEmpty ? tr("Nouvelle roue") : titre,
            options: libelles.enumerated().map { OptionRoue(label: $0.element, ordre: $0.offset) },
            paletteID: Reglages.paletteParDefaut
        )
        contexte.insert(roue)
        importAffiche = false
        ouvrir(roue)
    }
}

/// Aperçu miniature d'une roue dans la grille.
struct VignetteRoue: View {

    let roue: Roue
    let estCourante: Bool
    var verrouillee = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoueCanvas(
                    segments: roue.optionsOrdonnees.prefix(12).map {
                        SegmentAffichage(id: $0.id, label: "", poids: $0.poidsValide)
                    },
                    palette: roue.palette
                )
                .opacity(verrouillee ? 0.45 : 1)
                if verrouillee {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                }
            }
            .frame(width: 84, height: 84)

            VStack(spacing: 2) {
                Text(roue.titre.isEmpty ? tr("Sans titre") : roue.titre)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(roue.resume)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Fond.carte, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(estCourante ? 0.8 : 0), lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

struct BoutonNouvelleRoue: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(.white.opacity(0.12), in: .circle)
                Text(tr("Nouvelle roue"))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text(verbatim: " ")
                    .font(.system(.caption2, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.white.opacity(0.06), in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
