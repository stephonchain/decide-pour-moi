import Foundation
import SwiftUI

// MARK: - Gabarits communs

/// Bouton principal des pages d'onboarding.
struct BoutonOnboarding: View {
    let titre: String
    var actif = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titre)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Fond.sombreProfond)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white, in: .capsule)
        }
        .disabled(!actif)
        .opacity(actif ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: actif)
    }
}

/// Question à choix unique : un tap répond et fait avancer.
struct PageQuestionSimple: View {
    let question: String
    /// Paires (identifiant, libellé).
    let options: [(String, String)]
    let selection: String?
    let repondre: (String) -> Void

    @State private var choix: String?

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Text(question)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                ForEach(options, id: \.0) { identifiant, libelle in
                    Button {
                        choix = identifiant
                        repondre(identifiant)
                    } label: {
                        HStack {
                            Text(libelle)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            if choix == identifiant {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(16)
                        .background(.white.opacity(choix == identifiant ? 0.18 : 0.08), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { choix = selection }
    }
}

// MARK: - Page 1 : accueil

struct PageAccueil: View {
    let continuer: () -> Void
    @State private var apparu = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            DemoRoueStatique()
                .frame(width: 190, height: 190)
                .scaleEffect(apparu ? 1 : 0.6)
                .opacity(apparu ? 1 : 0)

            VStack(spacing: 10) {
                Text(verbatim: tr("Décide pour moi"))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(tr("Arrêtez d'hésiter. Laissez la roue trancher."))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            Spacer()
            BoutonOnboarding(titre: tr("Commencer")) { continuer() }
        }
        .padding(24)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) { apparu = true }
        }
    }
}

/// Petite roue décorative qui tourne lentement, pour l'accueil.
struct DemoRoueStatique: View {
    @State private var angle: Double = 0

    var body: some View {
        RoueCanvas(
            segments: (0..<8).map { _ in SegmentAffichage(id: UUID(), label: "", poids: 1) },
            palette: Palette.toutes[0]
        )
        .rotationEffect(.radians(angle))
        .onAppear {
            withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
                angle = SpinEngine.tour
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Page 2 : démo libre (le moment magique)

struct PageDemoLibre: View {
    let surTirage: () -> Void
    let continuer: () -> Void

    @State private var aTire = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            DemoRoue(
                titre: tr("Ce soir on mange…"),
                labels: [tr("Pizza"), tr("Sushis"), tr("Burger"), tr("Pâtes"), tr("Salade"), tr("Restes du frigo")],
                palette: Palette.toutes[0],
                lancementAuto: true
            ) { _ in
                aTire = true
                surTirage()
            }

            Text(aTire ? tr("Et voilà : décidé.") : tr("Essayez, lancez-la : touchez le centre."))
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            Spacer(minLength: 8)
            BoutonOnboarding(titre: tr("Continuer"), actif: aTire) { continuer() }
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.25), value: aTire)
    }
}

// MARK: - Page 4 : validation + fait

struct PageValidation: View {
    let continuer: () -> Void

    private var accroche: String {
        switch ReponsesOnboarding.frequence ?? .souvent {
        case .toutLeTemps: tr("Tout le temps ? Vous n'êtes pas seul.")
        case .souvent: tr("Vous n'êtes pas seul.")
        case .parfois: tr("Même parfois, ça pèse.")
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.9))
            Text(accroche)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(tr("On prend environ 35 000 décisions par jour, et la fatigue décisionnelle est réelle : plus on tranche de petites choses, moins il reste d'énergie pour les grandes."))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
            BoutonOnboarding(titre: tr("Continuer")) { continuer() }
        }
        .padding(24)
    }
}

// MARK: - Page 5 : domaines (choix multiples)

struct PageDomaines: View {
    let continuer: () -> Void

    @State private var choisis: Set<ReponsesOnboarding.Domaine> = Set(ReponsesOnboarding.domaines)

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(tr("Où hésitez-vous le plus ?"))
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(tr("Plusieurs réponses possibles."))
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            VStack(spacing: 10) {
                ForEach(ReponsesOnboarding.Domaine.allCases) { domaine in
                    Button {
                        basculer(domaine)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: domaine.symbole)
                                .frame(width: 26)
                                .foregroundStyle(.white.opacity(0.85))
                            Text(domaine.libelle)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: choisis.contains(domaine) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(.white.opacity(choisis.contains(domaine) ? 1 : 0.35))
                        }
                        .padding(14)
                        .background(.white.opacity(choisis.contains(domaine) ? 0.18 : 0.08), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            BoutonOnboarding(titre: tr("Continuer"), actif: !choisis.isEmpty) {
                ReponsesOnboarding.domaines = ReponsesOnboarding.Domaine.allCases.filter { choisis.contains($0) }
                continuer()
            }
        }
        .padding(24)
    }

    private func basculer(_ domaine: ReponsesOnboarding.Domaine) {
        if choisis.contains(domaine) { choisis.remove(domaine) } else { choisis.insert(domaine) }
        Haptiques.shared.selection()
    }
}

// MARK: - Page 6 : démo ciblée

struct PageDemoCiblee: View {
    let surTirage: () -> Void
    let continuer: () -> Void

    @State private var aTire = false
    private let demo = ReponsesOnboarding.domaineDominant.demo

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            DemoRoue(
                titre: demo.titre,
                labels: demo.options,
                palette: Palette.toutes[2]
            ) { _ in
                aTire = true
                surTirage()
            }

            Text(aTire ? tr("Vous voyez l'idée.") : tr("Celle-ci est pour vous. Lancez-la."))
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            Spacer(minLength: 8)
            BoutonOnboarding(titre: tr("Continuer"), actif: aTire) { continuer() }
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.25), value: aTire)
    }
}

// MARK: - Page 8 : projection

struct PageProjection: View {
    let continuer: () -> Void

    private var heures: Int { (ReponsesOnboarding.tempsPerdu ?? .de10a30).heuresParMois }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text(verbatim: tr("≈ \(heures) h"))
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("C'est le temps que l'hésitation vous prend chaque mois, à ce rythme."))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Text(tr("Décide pour moi tranche en 5 secondes."))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Spacer()
            BoutonOnboarding(titre: tr("Continuer")) { continuer() }
        }
        .padding(24)
    }
}

// MARK: - Page 9 : ordre de passage

struct PageOrdreDePassage: View {
    let continuer: () -> Void

    @State private var lignesVisibles = 0
    private let noms = [tr("Léa"), tr("Marco"), tr("Aïcha"), tr("Tom"), tr("Nina")]

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text(tr("Le mode « Ordre de passage »"))
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                ForEach(Array(noms.enumerated()), id: \.offset) { position, nom in
                    HStack(spacing: 12) {
                        Text(verbatim: "\(position + 1)")
                            .font(.system(.body, design: .monospaced, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 28, alignment: .trailing)
                        Text(nom)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
                    .opacity(position < lignesVisibles ? 1 : 0)
                    .offset(x: position < lignesVisibles ? 0 : 24)
                }
            }
            .frame(maxWidth: 320)

            Text(tr("La roue enchaîne les tirages et construit la liste toute seule. Parfait pour les profs et les tournois."))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
            BoutonOnboarding(titre: tr("Continuer")) { continuer() }
        }
        .padding(24)
        .task {
            for position in 1...noms.count {
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    lignesVisibles = position
                }
                Haptiques.shared.selection()
            }
        }
    }
}

// MARK: - Page 10 : pondération

struct PagePonderation: View {
    let continuer: () -> Void

    @State private var accentue = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text(tr("La pondération"))
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)

            ZStack {
                RoueCanvas(
                    segments: [
                        SegmentAffichage(id: Self.idFixe0, label: tr("Pizza"), poids: accentue ? 3 : 1),
                        SegmentAffichage(id: Self.idFixe1, label: tr("Salade"), poids: 1),
                        SegmentAffichage(id: Self.idFixe2, label: tr("Sushis"), poids: 1)
                    ],
                    palette: Palette.toutes[0]
                )
                .id(accentue)
                .transition(.opacity)
            }
            .frame(width: 210, height: 210)
            .animation(.easeInOut(duration: 0.5), value: accentue)

            Text(tr("Donnez plus de chances à vos envies : une option ×3 occupe trois parts et sort trois fois plus souvent."))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
            BoutonOnboarding(titre: tr("Continuer")) { continuer() }
        }
        .padding(24)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.4))
                accentue.toggle()
            }
        }
    }

    private static let idFixe0 = UUID()
    private static let idFixe1 = UUID()
    private static let idFixe2 = UUID()
}

// MARK: - Page 12 : ce que la roue change

/// Pas de faux avis ni de faux chiffres : des bénéfices, formulés comme
/// des situations réelles.
struct PageBenefices: View {
    let continuer: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(tr("Ce que la roue change"))
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                CarteBenefice(
                    symbole: "fork.knife",
                    texte: tr("Fini les « je sais pas, et toi ? » : le dîner se décide en un geste.")
                )
                CarteBenefice(
                    symbole: "graduationcap.fill",
                    texte: tr("En classe, l'ordre de passage se tire au sort : plus de débat, plus de favoritisme.")
                )
                CarteBenefice(
                    symbole: "party.popper.fill",
                    texte: tr("En soirée, la roue devient le jeu : c'est elle qu'on accuse, jamais vous.")
                )
            }
            Spacer()
            BoutonOnboarding(titre: tr("Continuer")) { continuer() }
        }
        .padding(24)
    }
}

struct CarteBenefice: View {
    let symbole: String
    let texte: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbole)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.12), in: .circle)
            Text(texte)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.07), in: .rect(cornerRadius: 16))
    }
}

// MARK: - Page 13 : engagement

struct PageEngagement: View {
    let continuer: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.9))
            Text(tr("Prêt à ne plus jamais bloquer sur une décision ?"))
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Spacer()
            BoutonOnboarding(titre: tr("Je suis prêt")) { continuer() }
        }
        .padding(24)
    }
}

// MARK: - Page 14 : récapitulatif personnalisé

struct PageRecapitulatif: View {
    let continuer: () -> Void

    @State private var lignesVisibles = 0

    private var lignes: [String] {
        var resultat: [String] = []
        let domaines = ReponsesOnboarding.domaines
        if domaines.isEmpty {
            resultat.append(tr("Des roues pour toutes vos décisions"))
        } else {
            for domaine in domaines.prefix(3) {
                resultat.append(tr("Des roues pour \(domaine.complementDeNom)"))
            }
        }
        resultat.append(tr("Le mode ordre de passage"))
        resultat.append(tr("La pondération de vos envies"))
        resultat.append(tr("Des tirages illimités, vraiment aléatoires"))
        return resultat
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text(tr("Votre plan"))
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(lignes.enumerated()), id: \.offset) { position, ligne in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(hex: 0x4BC46B))
                            .scaleEffect(position < lignesVisibles ? 1 : 0.2)
                        Text(ligne)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .opacity(position < lignesVisibles ? 1 : 0)
                }
            }
            Spacer()
            BoutonOnboarding(titre: tr("Découvrir mon offre")) { continuer() }
        }
        .padding(24)
        .task {
            for position in 1...lignes.count {
                try? await Task.sleep(for: .seconds(0.45))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    lignesVisibles = position
                }
                Haptiques.shared.selection()
            }
        }
    }
}
