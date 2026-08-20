import Foundation
import Testing
@testable import DecidePourMoi

/// Générateur déterministe : les tests de distribution doivent être
/// reproductibles, sinon ils finissent par échouer un jour au hasard.
struct GenerateurDeterministe: RandomNumberGenerator {
    private var etat: UInt64

    init(graine: UInt64 = 0x9E3779B97F4A7C15) {
        etat = graine == 0 ? 1 : graine
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        etat ^= etat >> 12
        etat ^= etat << 25
        etat ^= etat >> 27
        return etat &* 2_685_821_657_736_338_717
    }
}

private func options(_ poids: [Int]) -> [SpinOption] {
    poids.map { SpinOption(poids: $0) }
}

@Suite("Découpage angulaire")
struct SpansTests {

    @Test("Les parts couvrent exactement le cercle")
    func couvertureComplete() {
        for nombre in [2, 3, 7, 12, 60] {
            let parts = SpinEngine.spans(options(Array(repeating: 1, count: nombre)))
            #expect(parts.count == nombre)
            #expect(parts.first?.debut == 0)
            #expect(abs((parts.last?.fin ?? 0) - SpinEngine.tour) < 1e-9)
            for (precedente, suivante) in zip(parts, parts.dropFirst()) {
                #expect(abs(precedente.fin - suivante.debut) < 1e-12)
            }
        }
    }

    @Test("Une option de poids 3 occupe trois fois plus de place")
    func partsProportionnelles() {
        let parts = SpinEngine.spans(options([1, 3, 2]))
        let total = SpinEngine.tour
        #expect(abs(parts[0].largeur - total * 1 / 6) < 1e-9)
        #expect(abs(parts[1].largeur - total * 3 / 6) < 1e-9)
        #expect(abs(parts[2].largeur - total * 2 / 6) < 1e-9)
    }

    @Test("Une roue vide ne produit aucune part")
    func roueVide() {
        #expect(SpinEngine.spans([]).isEmpty)
        #expect(SpinEngine.bornes([]).isEmpty)
        #expect(SpinEngine.tirer(parmi: []) == nil)
    }
}

@Suite("Équité du tirage")
struct TirageTests {

    @Test("Distribution uniforme sur 10 000 tirages")
    func distributionUniforme() {
        let jeu = options(Array(repeating: 1, count: 8))
        var generateur = GenerateurDeterministe(graine: 42)
        var comptes = [Int](repeating: 0, count: jeu.count)

        for _ in 0..<10_000 {
            guard let index = SpinEngine.tirer(parmi: jeu, avec: &generateur) else {
                Issue.record("Le tirage devrait toujours produire un index")
                return
            }
            comptes[index] += 1
        }

        #expect(comptes.reduce(0, +) == 10_000)
        let attendu = 10_000.0 / 8.0
        for compte in comptes {
            // ±20 % : largement au-dessus du bruit statistique, mais assez
            // serré pour attraper un vrai biais.
            #expect(abs(Double(compte) - attendu) < attendu * 0.2)
        }
    }

    @Test("Les poids se retrouvent dans les fréquences")
    func distributionPonderee() {
        let jeu = options([1, 2, 3])
        var generateur = GenerateurDeterministe(graine: 7)
        var comptes = [Int](repeating: 0, count: jeu.count)

        for _ in 0..<12_000 {
            if let index = SpinEngine.tirer(parmi: jeu, avec: &generateur) {
                comptes[index] += 1
            }
        }

        let total = Double(comptes.reduce(0, +))
        let attendus = [1.0 / 6, 2.0 / 6, 3.0 / 6]
        for (compte, attendu) in zip(comptes, attendus) {
            #expect(abs(Double(compte) / total - attendu) < 0.02)
        }
    }

    @Test("Part angulaire et probabilité vont toujours ensemble")
    func coherenceAngleProbabilite() {
        let jeu = options([1, 2, 3, 1])
        let parts = SpinEngine.spans(jeu)
        var generateur = GenerateurDeterministe(graine: 1234)
        var comptes = [Int](repeating: 0, count: jeu.count)

        for _ in 0..<20_000 {
            if let index = SpinEngine.tirer(parmi: jeu, avec: &generateur) {
                comptes[index] += 1
            }
        }

        let total = Double(comptes.reduce(0, +))
        for (index, part) in parts.enumerated() {
            let partAngulaire = part.largeur / SpinEngine.tour
            let frequence = Double(comptes[index]) / total
            #expect(abs(frequence - partAngulaire) < 0.02)
        }
    }

    @Test("Une seule option sort toujours")
    func optionUnique() {
        let jeu = options([1])
        var generateur = GenerateurDeterministe()
        for _ in 0..<50 {
            #expect(SpinEngine.tirer(parmi: jeu, avec: &generateur) == 0)
        }
    }
}

@Suite("Plan de rotation")
struct PlanTests {

    @Test("La roue s'arrête bien sur le segment gagnant")
    func atterrissageSurLeGagnant() {
        for nombre in [2, 3, 5, 8, 17, 60] {
            let jeu = options(Array(repeating: 1, count: nombre))
            for gagnant in stride(from: 0, to: nombre, by: max(1, nombre / 7)) {
                for angleDepart in [0.0, 1.3, 4.9, 6.2] {
                    for decalage in [-0.36, 0.0, 0.36] {
                        let plan = SpinEngine.plan(
                            options: jeu,
                            indexGagnant: gagnant,
                            angleActuel: angleDepart,
                            vitesseGeste: 9,
                            decalage: decalage
                        )
                        guard let plan else {
                            Issue.record("Plan manquant")
                            return
                        }
                        let atterrissage = SpinEngine.indexSousLePointeur(
                            angleRoue: plan.angleArrivee,
                            options: jeu
                        )
                        #expect(atterrissage == gagnant)
                    }
                }
            }
        }
    }

    @Test("Le gagnant est respecté même avec des poids")
    func atterrissagePondere() {
        let jeu = options([3, 1, 2, 1, 3])
        for gagnant in jeu.indices {
            let plan = SpinEngine.plan(
                options: jeu,
                indexGagnant: gagnant,
                angleActuel: 2.4,
                vitesseGeste: 20,
                decalage: 0.3
            )
            #expect(SpinEngine.indexSousLePointeur(angleRoue: plan!.angleArrivee, options: jeu) == gagnant)
        }
    }

    @Test("La durée reste entre 3 et 5 secondes")
    func dureeDansLesClous() {
        let jeu = options([1, 1, 1, 1])
        for vitesse in [0.0, 1.0, 5.0, 12.0, 25.0, 400.0] {
            let plan = SpinEngine.plan(options: jeu, indexGagnant: 0, angleActuel: 0, vitesseGeste: vitesse, decalage: 0)
            #expect(plan!.duree >= SpinEngine.dureeMin - 1e-9)
            #expect(plan!.duree <= SpinEngine.dureeMax + 1e-9)
        }
    }

    @Test("Un geste vif tourne plus longtemps qu'un geste mou")
    func vitesseInfluenceLaRotation() {
        let jeu = options([1, 1, 1])
        let mou = SpinEngine.plan(options: jeu, indexGagnant: 1, angleActuel: 0, vitesseGeste: 2, decalage: 0)!
        let vif = SpinEngine.plan(options: jeu, indexGagnant: 1, angleActuel: 0, vitesseGeste: 25, decalage: 0)!
        #expect(vif.duree > mou.duree)
        #expect(vif.rotationTotale > mou.rotationTotale)
    }

    @Test("Un index hors bornes ne produit pas de plan")
    func indexInvalide() {
        #expect(SpinEngine.plan(options: options([1, 1]), indexGagnant: 5, angleActuel: 0, vitesseGeste: 5) == nil)
        #expect(SpinEngine.plan(options: [], indexGagnant: 0, angleActuel: 0, vitesseGeste: 5) == nil)
    }

    @Test("La rotation ne repart jamais en arrière")
    func rotationToujoursPositive() {
        let jeu = options(Array(repeating: 1, count: 6))
        for angleDepart in stride(from: 0.0, to: SpinEngine.tour, by: 0.4) {
            for gagnant in jeu.indices {
                let plan = SpinEngine.plan(options: jeu, indexGagnant: gagnant, angleActuel: angleDepart, vitesseGeste: 8, decalage: 0)!
                #expect(plan.rotationTotale >= SpinEngine.toursMin * SpinEngine.tour - 1e-9)
            }
        }
    }
}

@Suite("Courbe et tics")
struct AmortissementTests {

    @Test("La courbe part de 0 et finit à 1, sans reculer")
    func courbeMonotone() {
        #expect(SpinEngine.amortissement(0) == 0)
        #expect(abs(SpinEngine.amortissement(1) - 1) < 1e-12)
        var precedent = -1.0
        for pas in 0...100 {
            let valeur = SpinEngine.amortissement(Double(pas) / 100)
            #expect(valeur >= precedent)
            precedent = valeur
        }
    }

    @Test("L'inverse de la courbe retombe sur ses pieds")
    func inverseCoherent() {
        for pas in 0...50 {
            let u = Double(pas) / 50
            let aller = SpinEngine.amortissement(u)
            #expect(abs(SpinEngine.amortissementInverse(aller) - u) < 1e-9)
        }
    }

    @Test("Il y a autant de tics que de séparations franchies")
    func nombreDeTics() {
        let jeu = options(Array(repeating: 1, count: 6))
        let plan = SpinEngine.plan(options: jeu, indexGagnant: 0, angleActuel: 0, vitesseGeste: 25, decalage: 0)!
        let instants = SpinEngine.instantsDesTics(plan: plan, options: jeu, maximum: 10_000)

        // 6 séparations par tour, sur la rotation totale parcourue.
        let attendu = Int((plan.rotationTotale / SpinEngine.tour) * 6)
        #expect(abs(instants.count - attendu) <= 6)
    }

    @Test("Les tics sont croissants et tiennent dans la durée du lancer")
    func ticsOrdonnes() {
        let jeu = options([1, 2, 1, 3, 1])
        let plan = SpinEngine.plan(options: jeu, indexGagnant: 3, angleActuel: 1.1, vitesseGeste: 15, decalage: 0.2)!
        let instants = SpinEngine.instantsDesTics(plan: plan, options: jeu)

        #expect(!instants.isEmpty)
        #expect(instants == instants.sorted())
        #expect(instants.first! >= 0)
        #expect(instants.last! <= plan.duree + 1e-9)
    }

    @Test("Les tics se resserrent au début et s'espacent à la fin")
    func ticsRalentissent() {
        let jeu = options(Array(repeating: 1, count: 8))
        let plan = SpinEngine.plan(options: jeu, indexGagnant: 2, angleActuel: 0, vitesseGeste: 25, decalage: 0)!
        let instants = SpinEngine.instantsDesTics(plan: plan, options: jeu, maximum: 10_000)
        let ecarts = zip(instants, instants.dropFirst()).map { $1 - $0 }

        #expect(ecarts.count > 10)
        let premiers = ecarts.prefix(5).reduce(0, +) / 5
        let derniers = ecarts.suffix(5).reduce(0, +) / 5
        #expect(derniers > premiers)
    }

    @Test("Le nombre de tics est plafonné")
    func ticsPlafonnes() {
        let jeu = options(Array(repeating: 1, count: 60))
        let plan = SpinEngine.plan(options: jeu, indexGagnant: 0, angleActuel: 0, vitesseGeste: 25, decalage: 0)!
        let instants = SpinEngine.instantsDesTics(plan: plan, options: jeu, maximum: 220)
        #expect(instants.count == 220)
        // Ce sont bien les derniers qui sont conservés : ceux de la toute
        // fin, quand la roue accroche segment après segment.
        #expect(instants.last! > plan.duree * 0.7)
    }

    @Test("Une roue à une seule option ne tique pas")
    func pasDeTicSansSeparation() {
        let jeu = options([1])
        let plan = SpinEngine.plan(options: jeu, indexGagnant: 0, angleActuel: 0, vitesseGeste: 10, decalage: 0)!
        #expect(SpinEngine.instantsDesTics(plan: plan, options: jeu).isEmpty)
    }
}

@Suite("Modes de tirage")
struct ModeTirageTests {

    @Test("Le mode sans remise vide la roue sans jamais répéter")
    func sansRemiseEpuiseLaRoue() {
        var restantes = options(Array(repeating: 1, count: 12))
        var generateur = GenerateurDeterministe(graine: 99)
        var sorties: [UUID] = []

        while !restantes.isEmpty {
            guard let index = SpinEngine.tirer(parmi: restantes, avec: &generateur) else { break }
            sorties.append(restantes[index].id)
            restantes.remove(at: index)
        }

        #expect(sorties.count == 12)
        #expect(Set(sorties).count == 12)
        #expect(restantes.isEmpty)
    }

    @Test("L'ordre de passage produit une permutation complète")
    func ordreDePassageComplet() {
        let jeu = options(Array(repeating: 1, count: 25))
        let attendus = Set(jeu.map(\.id))
        var restantes = jeu
        var generateur = GenerateurDeterministe(graine: 2024)
        var ordre: [UUID] = []

        while !restantes.isEmpty {
            let index = SpinEngine.tirer(parmi: restantes, avec: &generateur)!
            ordre.append(restantes.remove(at: index).id)
        }

        #expect(ordre.count == 25)
        #expect(Set(ordre) == attendus)
    }

    @Test("Les modes qui retirent l'option sont bien identifiés")
    func drapeauRetrait() {
        #expect(ModeTirage.avecRemise.retireLOptionTiree == false)
        #expect(ModeTirage.sansRemise.retireLOptionTiree)
        #expect(ModeTirage.ordreDePassage.retireLOptionTiree)
    }
}

@Suite("Utilitaires")
struct UtilitairesTests {

    @Test("Le modulo reste positif")
    func moduloPositif() {
        #expect(abs(SpinEngine.modulo(-0.5, SpinEngine.tour) - (SpinEngine.tour - 0.5)) < 1e-12)
        #expect(abs(SpinEngine.modulo(SpinEngine.tour * 3 + 1, SpinEngine.tour) - 1) < 1e-9)
        #expect(SpinEngine.modulo(0, SpinEngine.tour) == 0)
    }

    @Test("Le segment sous le pointeur suit la rotation")
    func segmentSousLePointeur() {
        let jeu = options(Array(repeating: 1, count: 4))
        // Roue à l'arrêt : le premier segment démarre au pointeur.
        #expect(SpinEngine.indexSousLePointeur(angleRoue: 0, options: jeu) == 0)
        // Un quart de tour dans le sens horaire ramène le dernier segment en haut.
        #expect(SpinEngine.indexSousLePointeur(angleRoue: .pi / 2, options: jeu) == 3)
        #expect(SpinEngine.indexSousLePointeur(angleRoue: .pi, options: jeu) == 2)
        #expect(SpinEngine.indexSousLePointeur(angleRoue: 0, options: []) == nil)
    }

    @Test("Les libellés trop longs sont tronqués proprement")
    func troncatureLibelle() {
        #expect(RoueCanvas.tronquer("  Pizza  ") == "Pizza")
        let long = String(repeating: "a", count: 40)
        let tronque = RoueCanvas.tronquer(long)
        #expect(tronque.count == RoueCanvas.longueurMaxLibelle)
        #expect(tronque.hasSuffix("…"))
    }
}
