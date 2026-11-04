import Foundation
import SwiftUI

// MARK: - Gabarits communs

/// Gabarit d'une page d'onboarding : contenu centré, action en bas. Les
/// quinze pages partagent la même ossature — c'est ce qui donne au parcours
/// son rythme, chaque page n'ayant plus qu'à poser son contenu.
struct PageOnboarding<Contenu: View>: View {
    private let espacement: CGFloat
    private let contenu: Contenu
    private let bas: AnyView

    init(
        espacement: CGFloat = 28,
        @ViewBuilder contenu: () -> Contenu,
        @ViewBuilder bas: () -> some View
    ) {
        self.espacement = espacement
        self.contenu = contenu()
        self.bas = AnyView(bas())
    }

    /// Variante sans pied de page : les questions se terminent sur le choix,
    /// rien à poser sous elles.
    init(espacement: CGFloat = 28, @ViewBuilder contenu: () -> Contenu) {
        self.espacement = espacement
        self.contenu = contenu()
        self.bas = AnyView(EmptyView())
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: espacement) {
                contenu
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            bas
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 34)
    }
}

/// Bouton principal des pages d'onboarding.
struct BoutonOnboarding: View {
    let titre: String
    var actif = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(titre)
                .boutonPrincipal()
        }
        .disabled(!actif)
        .opacity(actif ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.2), value: actif)
    }
}

/// Question à choix unique : un tap répond et fait avancer.
struct PageQuestionSimple: View {
    /// Rang de la question dans le parcours, pour le surtitre : savoir
    /// combien il en reste vaut mieux qu'une barre qui avance toute seule.
    let rang: Int
    let question: String
    /// Triplets (identifiant, libellé, symbole de la puce).
    let options: [(String, String, String)]
    let selection: String?
    let repondre: (String) -> Void

    @State private var choix: String?

    private var teintes: [Color] { Palette.toutes[0].teintes }

    var body: some View {
        PageOnboarding(espacement: 32) {
            VStack(alignment: .leading, spacing: 10) {
                Surtitre(texte: tr("Question \(rang) sur 4"))
                TitrePage(texte: question)
            }

            VStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    CarteChoix(libelle: option.1, choisie: choix == option.0) {
                        PuceOption(couleur: teintes[index % teintes.count], symbole: option.2)
                    } action: {
                        choix = option.0
                        repondre(option.0)
                    }
                }
            }
        }
        .onAppear { choix = selection }
    }
}

// MARK: - Page 1 : accueil

struct PageAccueil: View {
    let continuer: () -> Void
    @State private var apparu = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            DemoRoueStatique()
                .frame(width: 250, height: 250)
                .scaleEffect(apparu ? 1 : 0.6)
                .opacity(apparu ? 1 : 0)

            VStack(spacing: 12) {
                Text(verbatim: tr("Décide pour moi"))
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Encre.vive)
                    .multilineTextAlignment(.center)
                Text(tr("Arrêtez d'hésiter. Laissez la roue trancher."))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Encre.douce)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            BoutonOnboarding(titre: tr("Commencer")) { continuer() }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
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

// MARK: - Pages 2 et 6 : les démos

/// Les deux pages où l'on touche la roue pour de vrai. Même gabarit : un
/// surtitre, le titre de la roue, la roue, puis l'indice ou le résultat.
struct PageDemo: View {
    let surtitre: String
    let titre: String
    let labels: [String]
    let palette: Palette
    var lancementAuto = false
    let indice: String
    let apresTirage: String
    let surTirage: () -> Void
    let continuer: () -> Void

    @State private var aTire = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Surtitre(texte: surtitre)
                Text(titre)
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(Encre.vive)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            Spacer(minLength: 12)

            DemoRoue(
                titre: "",
                labels: labels,
                palette: palette,
                lancementAuto: lancementAuto
            ) { _ in
                aTire = true
                surTirage()
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                if !aTire {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Accent.soleil)
                }
                Text(aTire ? apresTirage : indice)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Encre.douce)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 54)

            BoutonOnboarding(titre: tr("Continuer"), actif: aTire) { continuer() }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
        .animation(.easeInOut(duration: 0.25), value: aTire)
    }
}

struct PageDemoLibre: View {
    let surTirage: () -> Void
    let continuer: () -> Void

    var body: some View {
        PageDemo(
            surtitre: tr("À vous de jouer"),
            titre: tr("Ce soir on mange…"),
            labels: [tr("Pizza"), tr("Sushis"), tr("Burger"), tr("Pâtes"), tr("Salade"), tr("Restes du frigo")],
            palette: Palette.toutes[0],
            lancementAuto: true,
            indice: tr("Essayez, lancez-la : touchez le centre."),
            apresTirage: tr("Et voilà : décidé."),
            surTirage: surTirage,
            continuer: continuer
        )
    }
}

struct PageDemoCiblee: View {
    let surTirage: () -> Void
    let continuer: () -> Void

    private let demo = ReponsesOnboarding.domaineDominant.demo

    var body: some View {
        PageDemo(
            surtitre: tr("À vous de jouer"),
            titre: demo.titre,
            labels: demo.options,
            palette: Palette.toutes[2],
            indice: tr("Celle-ci est pour vous. Lancez-la."),
            apresTirage: tr("Vous voyez l'idée."),
            surTirage: surTirage,
            continuer: continuer
        )
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
        PageOnboarding(espacement: 36) {
            BullesDHesitation()
            VStack(alignment: .leading, spacing: 14) {
                Text(accroche)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Encre.vive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                TextePage(texte: tr("On prend environ 35 000 décisions par jour, et la fatigue décisionnelle est réelle : plus on tranche de petites choses, moins il reste d'énergie pour les grandes."))
            }
        } bas: {
            BoutonOnboarding(titre: tr("Continuer")) { continuer() }
        }
    }
}

/// Les hésitations du quotidien, en bulles qui flottent. Dessinées plutôt
/// qu'illustrées : une icône de cerveau disait la fatigue, ces bulles la
/// font entendre.
struct BullesDHesitation: View {
    @State private var flotte = false

    private struct Bulle {
        let texte: String
        let couleur: Color
        let aGauche: Bool
        let haut: CGFloat
        let inclinaison: Double
        let duree: Double
    }

    /// Calculées à l'affichage : un `static let` figerait la traduction
    /// dans la langue du premier lancement.
    private var bulles: [Bulle] {
        let teintes = Palette.toutes[0].teintes
        return [
            Bulle(texte: tr("Pizza ou sushis ?"), couleur: teintes[0], aGauche: true, haut: 0, inclinaison: -4, duree: 3.2),
            Bulle(texte: tr("On regarde quoi ?"), couleur: teintes[4], aGauche: false, haut: 64, inclinaison: 3, duree: 3.8),
            Bulle(texte: tr("Qui fait la vaisselle ?"), couleur: teintes[2], aGauche: true, haut: 132, inclinaison: -2, duree: 3.5),
            Bulle(texte: tr("Je sais pas, et toi ?"), couleur: teintes[6], aGauche: false, haut: 196, inclinaison: 4, duree: 4.0)
        ]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(bulles.enumerated()), id: \.offset) { _, bulle in
                Text(bulle.texte)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(bulle.couleur.estClaire ? Fond.sombre : Encre.vive)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(bulle.couleur, in: .rect(cornerRadius: 22))
                    .rotationEffect(.degrees(bulle.inclinaison))
                    .offset(y: bulle.haut + (flotte ? -6 : 0))
                    .frame(maxWidth: .infinity, alignment: bulle.aGauche ? .leading : .trailing)
                    .animation(
                        .easeInOut(duration: bulle.duree).repeatForever(autoreverses: true),
                        value: flotte
                    )
            }
        }
        .frame(height: 250, alignment: .top)
        .accessibilityHidden(true)
        .onAppear { flotte = true }
    }
}

// MARK: - Page 5 : domaines (choix multiples)

struct PageDomaines: View {
    let continuer: () -> Void

    @State private var choisis: Set<ReponsesOnboarding.Domaine> = Set(ReponsesOnboarding.domaines)

    /// Deuxième des quatre questions du parcours.
    private static let rang = 2

    private var teintes: [Color] { Palette.toutes[0].teintes }

    var body: some View {
        PageOnboarding {
            VStack(alignment: .leading, spacing: 10) {
                Surtitre(texte: tr("Question \(Self.rang) sur 4"))
                TitrePage(texte: tr("Où hésitez-vous le plus ?"))
                Text(tr("Plusieurs réponses possibles."))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Encre.discrete)
            }

            VStack(spacing: 10) {
                ForEach(Array(ReponsesOnboarding.Domaine.allCases.enumerated()), id: \.element.id) { index, domaine in
                    CarteChoix(libelle: domaine.libelle, choisie: choisis.contains(domaine)) {
                        PuceOption(couleur: teintes[index % teintes.count], symbole: domaine.symbole)
                    } action: {
                        basculer(domaine)
                    }
                }
            }
        } bas: {
            BoutonOnboarding(titre: tr("Continuer"), actif: !choisis.isEmpty) {
                ReponsesOnboarding.domaines = ReponsesOnboarding.Domaine.allCases.filter { choisis.contains($0) }
                continuer()
            }
        }
    }

    private func basculer(_ domaine: ReponsesOnboarding.Domaine) {
        if choisis.contains(domaine) { choisis.remove(domaine) } else { choisis.insert(domaine) }
        Haptiques.shared.selection()
    }
}

// MARK: - Page 8 : projection

struct PageProjection: View {
    let continuer: () -> Void

    private var heures: Int { (ReponsesOnboarding.tempsPerdu ?? .de10a30).heuresParMois }

    var body: some View {
        PageOnboarding(espacement: 22) {
            Spacer(minLength: 0)
            Text(verbatim: tr("≈ \(heures) h"))
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(Accent.soleil)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextePage(texte: tr("C'est le temps que l'hésitation vous prend chaque mois, à ce rythme."))
            Text(tr("Décide pour moi tranche en 5 secondes."))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Encre.vive)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        } bas: {
            BoutonOnboarding(titre: tr("Continuer")) { continuer() }
        }
    }
}

// MARK: - Page 9 : ordre de passage

struct PageOrdreDePassage: View {
    let continuer: () -> Void

    @State private var lignesVisibles = 0
    private let noms = [tr("Léa"), tr("Marco"), tr("Aïcha"), tr("Tom"), tr("Nina")]

    private var teintes: [Color] { Palette.toutes[0].teintes }

    var body: some View {
        PageOnboarding {
            VStack(alignment: .leading, spacing: 10) {
                BadgePremium()
                TitrePage(texte: tr("Le mode « Ordre de passage »"))
            }

            VStack(spacing: 10) {
                ForEach(Array(noms.enumerated()), id: \.offset) { position, nom in
                    HStack(spacing: 14) {
                        Text(verbatim: "\(position + 1)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Fond.sombre)
                            .frame(width: 40, height: 40)
                            .background(teintes[position % teintes.count], in: .rect(cornerRadius: 12))
                        Text(nom)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Encre.vive)
                        Spacer()
                        if position == 0 {
                            Text(tr("commence"))
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Encre.discrete)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 60)
                    .background(Fond.carte, in: .rect(cornerRadius: 18))
                    .opacity(position < lignesVisibles ? 1 : 0)
                    .offset(x: position < lignesVisibles ? 0 : 28)
                }
            }

            TextePage(texte: tr("La roue enchaîne les tirages et construit la liste toute seule. Parfait pour les profs et les tournois."))
        } bas: {
            BoutonOnboarding(titre: tr("Continuer")) { continuer() }
        }
        .task {
            for position in 1...noms.count {
                try? await Task.sleep(for: .seconds(0.45))
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

    /// Le poids se règle à la main : voir la part grossir sous son propre
    /// doigt explique la pondération mieux qu'une animation automatique.
    @State private var poids = 3

    var body: some View {
        PageOnboarding(espacement: 26) {
            VStack(alignment: .leading, spacing: 10) {
                BadgePremium()
                TitrePage(texte: tr("La pondération"))
            }

            RoueCanvas(
                segments: [
                    SegmentAffichage(id: Self.idFixe0, label: tr("Pizza"), poids: poids),
                    SegmentAffichage(id: Self.idFixe1, label: tr("Salade"), poids: 1),
                    SegmentAffichage(id: Self.idFixe2, label: tr("Sushis"), poids: 1)
                ],
                palette: Palette.toutes[0]
            )
            .frame(width: 230, height: 230)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.35), value: poids)

            HStack(spacing: 14) {
                Circle()
                    .fill(Palette.toutes[0].teintes[0])
                    .frame(width: 14, height: 14)
                Text(tr("Pizza"))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Encre.vive)
                Spacer()
                HStack(spacing: 4) {
                    Button { reglerLePoids(poids - 1) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Encre.vive)
                            .frame(width: 44, height: 44)
                            .background(Fond.carteChoisie, in: .rect(cornerRadius: 12))
                    }
                    .accessibilityLabel(Text(tr("Diminuer le poids")))

                    Text(verbatim: "×\(poids)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Accent.soleil)
                        .frame(width: 44)

                    Button { reglerLePoids(poids + 1) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Encre.vive)
                            .frame(width: 44, height: 44)
                            .background(Fond.carteChoisie, in: .rect(cornerRadius: 12))
                    }
                    .accessibilityLabel(Text(tr("Augmenter le poids")))
                }
                .padding(4)
                .background(Fond.sombre, in: .rect(cornerRadius: 16))
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .background(Fond.carte, in: .rect(cornerRadius: 20))

            TextePage(texte: tr("Donnez plus de chances à vos envies : une option ×3 occupe trois parts et sort trois fois plus souvent."))
        } bas: {
            BoutonOnboarding(titre: tr("Continuer")) { continuer() }
        }
    }

    private func reglerLePoids(_ nouveau: Int) {
        let borne = min(max(nouveau, 1), 5)
        guard borne != poids else { return }
        poids = borne
        Haptiques.shared.selection()
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
        PageOnboarding(espacement: 26) {
            TitrePage(texte: tr("Ce que la roue change"))

            VStack(spacing: 12) {
                CarteBenefice(
                    symbole: "fork.knife",
                    couleur: Palette.toutes[0].teintes[0],
                    titre: tr("À table"),
                    texte: tr("Fini les « je sais pas, et toi ? » : le dîner se décide en un geste.")
                )
                CarteBenefice(
                    symbole: "graduationcap.fill",
                    couleur: Palette.toutes[0].teintes[5],
                    titre: tr("En classe"),
                    texte: tr("En classe, l'ordre de passage se tire au sort : plus de débat, plus de favoritisme.")
                )
                CarteBenefice(
                    symbole: "party.popper.fill",
                    couleur: Palette.toutes[0].teintes[6],
                    titre: tr("En soirée"),
                    texte: tr("En soirée, la roue devient le jeu : c'est elle qu'on accuse, jamais vous.")
                )
            }
        } bas: {
            BoutonOnboarding(titre: tr("Continuer")) { continuer() }
        }
    }
}

struct CarteBenefice: View {
    let symbole: String
    let couleur: Color
    let titre: String
    let texte: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                PuceOption(couleur: couleur, symbole: symbole)
                    .frame(width: 40, height: 40)
                Text(titre)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Encre.vive)
            }
            Text(texte)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Encre.douce)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Fond.carte, in: .rect(cornerRadius: 22))
    }
}

// MARK: - Page 13 : engagement

struct PageEngagement: View {
    let continuer: () -> Void

    var body: some View {
        PageOnboarding(espacement: 24) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Accent.soleil)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(tr("Prêt à ne plus jamais bloquer sur une décision ?"))
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Encre.vive)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        } bas: {
            BoutonOnboarding(titre: tr("Je suis prêt")) { continuer() }
        }
    }
}

// MARK: - Page 14 : récapitulatif personnalisé

struct PageRecapitulatif: View {
    let continuer: () -> Void

    @State private var lignesVisibles = 0

    private var teintes: [Color] { Palette.toutes[0].teintes }

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
        PageOnboarding(espacement: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Surtitre(texte: tr("Votre plan est prêt"))
                TitrePage(texte: tr("Votre plan"))
            }

            VStack(spacing: 0) {
                ForEach(Array(lignes.enumerated()), id: \.offset) { position, ligne in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(teintes[position % teintes.count])
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(Fond.sombre)
                        }
                        .frame(width: 30, height: 30)
                        .scaleEffect(position < lignesVisibles ? 1 : 0.3)

                        Text(ligne)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(Encre.vive)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 56)
                    .opacity(position < lignesVisibles ? 1 : 0)

                    if position < lignes.count - 1 {
                        Divider().overlay(Color.white.opacity(0.08))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Fond.carte, in: .rect(cornerRadius: 24))
        } bas: {
            BoutonOnboarding(titre: tr("Découvrir mon offre")) { continuer() }
        }
        .task {
            for position in 1...lignes.count {
                try? await Task.sleep(for: .seconds(0.4))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    lignesVisibles = position
                }
                Haptiques.shared.selection()
            }
        }
    }
}
