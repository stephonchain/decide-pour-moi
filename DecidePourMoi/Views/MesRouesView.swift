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
                if !premium.acces.estPremium && !premium.acces.estHistorique {
                    BandeauPremium { presenterPaywall(.roueVerrouillee) }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                LazyVGrid(columns: colonnes, spacing: 12) {
                    ForEach(Array(roues.enumerated()), id: \.element.id) { rang, roue in
                        let ouvrable = premium.acces.peutOuvrir(roue)
                        VignetteRoue(roue: roue, estCourante: roue.id == roueCourante.id, verrouillee: !ouvrable)
                            // Une vignette = un seul élément d'accessibilité,
                            // annoncé comme un bouton : VoiceOver l'atteint
                            // d'un geste, et les captures automatiques aussi.
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("roue.\(rang)")
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

                BoutonNouvelleRoue(verrouille: !peutCreer) { creer() }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                Button {
                    if peutCreer {
                        importAffiche = true
                    } else {
                        presenterPaywall(.creationDeRoue)
                    }
                } label: {
                    Label(tr("Coller une liste pour créer une roue"), systemImage: "doc.on.clipboard")
                        .boutonBarre()
                }
                .accessibilityIdentifier("bouton.collerListe")
                .padding(.horizontal, 16)
                .padding(.top, 10)

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
        VStack(alignment: .leading, spacing: 12) {
            RoueCanvas(
                segments: roue.optionsOrdonnees.prefix(12).map {
                    SegmentAffichage(id: $0.id, label: "", poids: $0.poidsValide)
                },
                palette: roue.palette
            )
            .frame(width: 74, height: 74)
            .opacity(verrouillee ? 0.55 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(roue.titre.isEmpty ? tr("Sans titre") : roue.titre)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Encre.vive)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(roue.resume)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Encre.discrete)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .padding(14)
        .background(Fond.carte, in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(estCourante ? Accent.soleil : .clear, lineWidth: 2)
        }
        // Le cadenas se pose sur la vignette, il ne remplace pas la roue :
        // on doit voir ce qu'on n'a pas encore.
        .overlay(alignment: .topTrailing) {
            if verrouillee {
                PastilleCadenas()
                    .padding(12)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Appel au premium en tête de « Mes roues » : la seule carte jaune de
/// l'écran, et elle dit ce qu'elle débloque avant de demander quoi que ce
/// soit.
struct BandeauPremium: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "star.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Accent.soleil)
                    .frame(width: 40, height: 40)
                    .background(Fond.sombre, in: .rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Débloquez toutes les roues"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                    Text(tr("3 jours gratuits, sans engagement"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .opacity(0.8)
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
            }
            .foregroundStyle(Fond.sombre)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Accent.soleil, in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

/// Création d'une roue : un contour pointillé plutôt qu'une carte pleine.
/// Ce n'est pas une roue de plus dans la grille, c'est une place à prendre.
struct BoutonNouvelleRoue: View {
    var verrouille = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .black))
                Text(tr("Nouvelle roue"))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                if verrouille { Cadenas() }
            }
            .foregroundStyle(Encre.vive)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        .white.opacity(0.22),
                        style: StrokeStyle(lineWidth: 2, dash: [7, 6])
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
