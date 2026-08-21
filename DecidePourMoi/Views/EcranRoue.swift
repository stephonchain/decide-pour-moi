import StoreKit
import SwiftData
import Foundation
import SwiftUI

/// Écran racine : la roue plein écran, prête à tourner dès l'ouverture.
struct EcranRoue: View {

    @Bindable var roue: Roue

    @Environment(\.modelContext) private var contexte
    @Environment(\.requestReview) private var demanderUnAvis
    @Environment(\.accessibilityReduceMotion) private var mouvementReduit

    @State private var controleur = ControleurDeRoue()
    @State private var mesRouesAffichees = false
    @State private var editionAffichee = false
    @State private var reglagesAffichees = false
    @State private var historiqueAffiche = false
    @State private var angleDuDoigt: Double? = nil

    @AppStorage(CleReglage.confettis) private var confettis = Reglages.confettisParDefaut
    @State private var premium = PremiumManager.shared
    @State private var contextePaywall: ContextePaywall? = nil

    var body: some View {
        ZStack {
            FondApplication()

            VStack(spacing: 0) {
                enTete
                Spacer(minLength: 8)
                roueInteractive
                Spacer(minLength: 8)
                basDeLEcran
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if let gagnante = controleur.resultat {
                OverlayResultat(
                    label: gagnante.label,
                    roue: roue,
                    compteur: controleur.compteurResultats,
                    confettisActifs: confettis && !mouvementReduit,
                    retraitAutorise: premium.acces.retraitAutorise,
                    relancer: { controleur.relancer(roue: roue, contexte: contexte, apresLeTirage: apresLeTirage) },
                    retirer: { retirer(gagnante) },
                    fermer: { controleur.resultat = nil }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: controleur.resultat?.id)
        .sheet(isPresented: $mesRouesAffichees) {
            MesRouesView(roueCourante: roue) { choisie in
                ouvrir(choisie)
            }
        }
        .sheet(isPresented: $editionAffichee) {
            EditionRoueView(roue: roue, estUneCreation: false)
        }
        .sheet(isPresented: $reglagesAffichees) {
            ReglagesView()
        }
        .sheet(isPresented: $historiqueAffiche) {
            HistoriqueView(roue: roue)
        }
        .sheet(item: $contextePaywall) { contextePaywall in
            PaywallAdapte(contexte: contextePaywall)
        }
        .task {
            Haptiques.shared.preparer()
            controleur.positionnerAuRepos(options: roue.optionsMoteur)
        }
        .onDisappear { controleur.annulerLancer() }
    }

    // MARK: En-tête

    private var enTete: some View {
        HStack(spacing: 12) {
            Button {
                Haptiques.shared.selection()
                mesRouesAffichees = true
            } label: {
                Image(systemName: "square.grid.2x2.fill")
                    .boutonRond()
            }
            .accessibilityLabel(Text(tr("Mes roues")))
            .accessibilityIdentifier("bouton.mesRoues")

            VStack(spacing: 2) {
                Text(roue.titre.isEmpty ? tr("Sans titre") : roue.titre)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(sousTitre)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)

            Button {
                Haptiques.shared.selection()
                editionAffichee = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .boutonRond()
            }
            .accessibilityLabel(Text(tr("Modifier la roue")))
            .accessibilityIdentifier("bouton.edition")
        }
        .padding(.top, 4)
    }

    private var sousTitre: String {
        if roue.mode == .avecRemise { return roue.resume }
        return "\(roue.mode.titre) · \(roue.resume)"
    }

    // MARK: La roue

    private var roueInteractive: some View {
        GeometryReader { geometrie in
            let cote = min(geometrie.size.width, geometrie.size.height)
            let centre = CGPoint(x: geometrie.size.width / 2, y: geometrie.size.height / 2)

            ZStack {
                if roue.estEpuisee {
                    RoueEpuisee { reinitialiser() }
                        .frame(width: cote, height: cote)
                } else {
                    disque(cote: cote)
                    PointeurRoue()
                        .frame(width: cote * 0.11, height: cote * 0.17)
                        .offset(y: -cote / 2 + cote * 0.055)

                    Button {
                        lancerParTap()
                    } label: {
                        MoyeuRoue(enRotation: controleur.enRotation, couleur: roue.palette.teintes.first ?? .accentColor)
                            .frame(width: cote * 0.22, height: cote * 0.22)
                    }
                    .buttonStyle(.plain)
                    .disabled(controleur.enRotation || !roue.peutTourner)
                    .accessibilityIdentifier("bouton.moyeu")
                    .accessibilityLabel(Text(tr("Tourner la roue")))
                    .accessibilityHint(Text(tr("Lance un tirage au sort parmi \(roue.optionsActives.count) options")))
                }
            }
            .frame(width: geometrie.size.width, height: geometrie.size.height)
            .contentShape(Circle())
            .gesture(gesteDeLancement(centre: centre))
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 520)
    }

    private func disque(cote: CGFloat) -> some View {
        TimelineView(.animation(paused: !controleur.enRotation)) { temps in
            RoueCanvas(segments: segments, palette: roue.palette)
                .rotationEffect(.radians(controleur.angleAffiche(a: temps.date)))
        }
        .frame(width: cote, height: cote)
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
    }

    private var segments: [SegmentAffichage] {
        roue.optionsActives.map {
            SegmentAffichage(id: $0.id, label: $0.label, poids: $0.poidsValide)
        }
    }

    // MARK: Bas d'écran

    private var basDeLEcran: some View {
        VStack(spacing: 14) {
            if roue.mode == .ordreDePassage, !roue.ordreDePassage.isEmpty {
                BandeauOrdreDePassage(roue: roue) { reinitialiser() }
            }

            HStack(spacing: 10) {
                Button {
                    Haptiques.shared.selection()
                    if premium.acces.historiqueAutorise {
                        historiqueAffiche = true
                    } else {
                        contextePaywall = .historique
                    }
                } label: {
                    HStack(spacing: 6) {
                        Label(tr("Historique"), systemImage: "clock.arrow.circlepath")
                        if !premium.acces.historiqueAutorise { Cadenas() }
                    }
                    .boutonSecondaire()
                }

                if roue.mode.retireLOptionTiree {
                    Button {
                        reinitialiser()
                    } label: {
                        Label(tr("Réinitialiser"), systemImage: "arrow.counterclockwise")
                            .boutonSecondaire()
                    }
                    .disabled(roue.optionsActives.count == roue.optionsOrdonnees.count)
                }

                Button {
                    Haptiques.shared.selection()
                    reglagesAffichees = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .boutonSecondaireCompact()
                }
                .accessibilityLabel(Text(tr("Réglages")))
                .accessibilityIdentifier("bouton.reglages")
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
    }

    // MARK: Gestes et actions

    private func gesteDeLancement(centre: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { valeur in
                guard !controleur.enRotation, roue.peutTourner else { return }
                let nouvel = Self.angleDuPoint(valeur.location, centre: centre)
                if let precedent = angleDuDoigt {
                    var delta = nouvel - precedent
                    if delta > .pi { delta -= SpinEngine.tour }
                    if delta < -.pi { delta += SpinEngine.tour }
                    controleur.suivreLeDoigt(delta: delta)
                }
                angleDuDoigt = nouvel
            }
            .onEnded { valeur in
                angleDuDoigt = nil
                guard !controleur.enRotation, roue.peutTourner else { return }
                let vitesse = vitesseAngulaire(valeur: valeur, centre: centre)
                guard abs(vitesse) >= ControleurDeRoue.vitesseDeclenchement else { return }
                controleur.lancer(roue: roue, vitesseGeste: vitesse, contexte: contexte, apresLeTirage: apresLeTirage)
            }
    }

    /// Angle du doigt vu du centre de la roue, en radians, sens horaire.
    /// Le calcul reste en `Double` de bout en bout pour éviter toute ambiguïté
    /// entre les surcharges `Double` et `CGFloat` des fonctions trigonométriques.
    private static func angleDuPoint(_ point: CGPoint, centre: CGPoint) -> Double {
        atan2(Double(point.y - centre.y), Double(point.x - centre.x))
    }

    /// Vitesse angulaire du geste, en rad/s : c'est la composante tangentielle
    /// de la vitesse du doigt, ramenée à la distance au centre.
    private func vitesseAngulaire(valeur: DragGesture.Value, centre: CGPoint) -> Double {
        let rayonX = Double(valeur.location.x - centre.x)
        let rayonY = Double(valeur.location.y - centre.y)
        let distance = (rayonX * rayonX + rayonY * rayonY).squareRoot()
        guard distance > 24 else { return 0 }
        let produitVectoriel = rayonX * Double(valeur.velocity.height)
            - rayonY * Double(valeur.velocity.width)
        return produitVectoriel / (distance * distance)
    }

    private func lancerParTap() {
        guard roue.peutTourner else { return }
        // Un tap n'a pas d'élan : on prend une vitesse moyenne.
        controleur.lancer(roue: roue, vitesseGeste: 12, contexte: contexte, apresLeTirage: apresLeTirage)
    }

    private func apresLeTirage() {
        DemandeDAvis.apresUnTirage(demanderUnAvis)
    }

    private func retirer(_ option: OptionRoue) {
        // Retirer une option à la volée bascule la roue en mode sans remise :
        // c'est donc une fonction premium comme le mode lui-même.
        guard premium.acces.retraitAutorise else {
            controleur.resultat = nil
            contextePaywall = .modeDeTirage
            return
        }
        if roue.mode == .avecRemise { roue.mode = .sansRemise }
        option.retiree = true
        roue.modifieeLe = .now
        controleur.resultat = nil
        Haptiques.shared.selection()
    }

    private func reinitialiser() {
        roue.reinitialiserTirages()
        controleur.resultat = nil
        Haptiques.shared.succes()
    }

    /// Ouvrir une roue, c'est simplement la remonter en tête : la racine
    /// affiche toujours la plus récemment utilisée.
    private func ouvrir(_ choisie: Roue) {
        mesRouesAffichees = false
        choisie.utiliseeLe = .now
    }
}

/// Écran affiché quand toutes les options sont sorties de la roue.
struct RoueEpuisee: View {
    let reinitialiser: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.9))
            Text(tr("Toutes les options sont sorties."))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button(action: reinitialiser) {
                Label(tr("Tout remettre en jeu"), systemImage: "arrow.counterclockwise")
                    .boutonPrincipal()
            }
        }
        .padding(28)
    }
}

/// Fond de l'app : le dégradé indigo profond de l'icône.
struct FondApplication: View {
    var body: some View {
        LinearGradient(
            colors: [Fond.sombre, Fond.sombreProfond],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
