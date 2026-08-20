import Foundation

// MARK: - Entrées / sorties du moteur

/// Option telle que vue par le moteur : un identifiant et un poids.
/// Type pur, sans dépendance SwiftData ni SwiftUI, pour rester testable.
struct SpinOption: Equatable, Hashable, Sendable {
    let id: UUID
    let poids: Int

    init(id: UUID = UUID(), poids: Int = 1) {
        self.id = id
        self.poids = max(1, poids)
    }
}

/// Part angulaire d'une option sur la roue, en radians, mesurée dans le sens
/// horaire depuis le repère « 12 h » de la roue.
struct SpanAngulaire: Equatable, Sendable {
    let debut: Double
    let fin: Double

    var centre: Double { (debut + fin) / 2 }
    var largeur: Double { fin - debut }
}

/// Plan de rotation complet, calculé d'un bloc avant l'animation.
/// L'animation ne fait que suivre ce plan : le gagnant est déjà connu,
/// aucun biais n'est possible.
struct SpinPlan: Equatable, Sendable {
    /// Angle de la roue au démarrage (radians, sens horaire).
    let angleDepart: Double
    /// Angle de la roue à l'arrivée.
    let angleArrivee: Double
    /// Durée totale de la décélération, en secondes.
    let duree: Double
    /// Index de l'option gagnante dans le tableau fourni.
    let indexGagnant: Int
    /// Exposant de la courbe d'amortissement.
    let exposant: Double

    /// Angle de la roue à l'instant `t` (0 ≤ t ≤ duree).
    func angle(a t: Double) -> Double {
        guard duree > 0 else { return angleArrivee }
        let u = min(max(t / duree, 0), 1)
        return angleDepart + (angleArrivee - angleDepart) * SpinEngine.amortissement(u, exposant: exposant)
    }

    /// Rotation totale parcourue, en radians.
    var rotationTotale: Double { angleArrivee - angleDepart }
}

// MARK: - Moteur

/// Moteur de tirage. Entièrement statique et pur : mêmes entrées, mêmes sorties.
enum SpinEngine {

    static let tour = 2 * Double.pi

    /// Bornes de vitesse de geste retenues (rad/s).
    static let vitesseMin: Double = 2
    static let vitesseMax: Double = 25

    /// Bornes de durée d'animation (secondes), conformes à la spec : 3 à 5 s.
    static let dureeMin: Double = 3.0
    static let dureeMax: Double = 5.0

    /// Nombre de tours complets, du plus mou au plus vif.
    static let toursMin: Double = 3
    static let toursMax: Double = 8

    /// Exposant de la courbe d'amortissement (ease-out prononcé).
    static let exposantParDefaut: Double = 3.6

    // MARK: Découpage angulaire

    /// Découpe la roue en parts proportionnelles aux poids.
    /// La somme des largeurs vaut exactement 2π.
    static func spans(_ options: [SpinOption]) -> [SpanAngulaire] {
        guard !options.isEmpty else { return [] }
        let total = Double(options.reduce(0) { $0 + max(1, $1.poids) })
        var curseur: Double = 0
        var resultat: [SpanAngulaire] = []
        resultat.reserveCapacity(options.count)
        for (index, option) in options.enumerated() {
            let largeur = tour * Double(max(1, option.poids)) / total
            // La dernière part ferme exactement le cercle, sans dérive de flottants.
            let fin = index == options.count - 1 ? tour : curseur + largeur
            resultat.append(SpanAngulaire(debut: curseur, fin: fin))
            curseur = fin
        }
        return resultat
    }

    /// Bornes entre segments (0 exclu, 2π exclu).
    static func bornes(_ options: [SpinOption]) -> [Double] {
        let s = spans(options)
        guard s.count > 1 else { return [] }
        return s.dropLast().map(\.fin)
    }

    // MARK: Tirage

    /// Tire une option au hasard, proportionnellement aux poids.
    /// Le générateur est injectable pour rendre la distribution testable.
    static func tirer<G: RandomNumberGenerator>(parmi options: [SpinOption], avec generateur: inout G) -> Int? {
        guard !options.isEmpty else { return nil }
        let total = options.reduce(0) { $0 + max(1, $1.poids) }
        var seuil = Int.random(in: 0..<total, using: &generateur)
        for (index, option) in options.enumerated() {
            seuil -= max(1, option.poids)
            if seuil < 0 { return index }
        }
        return options.count - 1
    }

    /// Tirage en production : générateur système, cryptographiquement solide.
    static func tirer(parmi options: [SpinOption]) -> Int? {
        var generateur = SystemRandomNumberGenerator()
        return tirer(parmi: options, avec: &generateur)
    }

    // MARK: Plan de rotation

    /// Construit le plan complet d'un lancer.
    ///
    /// - Parameters:
    ///   - options: les options encore en jeu, dans l'ordre d'affichage.
    ///   - indexGagnant: résultat déjà tiré (voir `tirer(parmi:)`).
    ///   - angleActuel: angle courant de la roue, en radians.
    ///   - vitesseGeste: vitesse du swipe en rad/s ; 0 pour un tap.
    ///   - decalage: position relative dans le segment gagnant, dans [-0.4, 0.4].
    ///               Injectable pour les tests ; aléatoire en production.
    static func plan(
        options: [SpinOption],
        indexGagnant: Int,
        angleActuel: Double,
        vitesseGeste: Double,
        decalage: Double = Double.random(in: -0.36...0.36)
    ) -> SpinPlan? {
        guard options.indices.contains(indexGagnant) else { return nil }
        let parts = spans(options)
        let part = parts[indexGagnant]

        let vitesse = min(max(abs(vitesseGeste), vitesseMin), vitesseMax)
        let intensite = (vitesse - vitesseMin) / (vitesseMax - vitesseMin)
        let duree = dureeMin + (dureeMax - dureeMin) * intensite
        let tours = (toursMin + (toursMax - toursMin) * intensite).rounded()

        // Angle local visé sous le pointeur, avec un décalage dans le segment
        // pour éviter que la roue s'arrête toujours pile au centre.
        let cible = part.centre + min(max(decalage, -0.4), 0.4) * part.largeur

        // Le pointeur est en haut : le point de la roue visible sous le pointeur
        // est celui dont l'angle local vaut -angleRoue (modulo 2π).
        // On veut donc angleArrivee ≡ -cible.
        let reste = modulo(-cible - angleActuel, tour)
        let arrivee = angleActuel + tours * tour + reste

        return SpinPlan(
            angleDepart: angleActuel,
            angleArrivee: arrivee,
            duree: duree,
            indexGagnant: indexGagnant,
            exposant: exposantParDefaut
        )
    }

    // MARK: Courbe d'amortissement

    /// Progression normalisée : départ vif, arrêt très amorti.
    static func amortissement(_ u: Double, exposant: Double = exposantParDefaut) -> Double {
        let borne = min(max(u, 0), 1)
        return 1 - pow(1 - borne, exposant)
    }

    /// Inverse de `amortissement`, pour retrouver l'instant d'une progression donnée.
    static func amortissementInverse(_ p: Double, exposant: Double = exposantParDefaut) -> Double {
        let borne = min(max(p, 0), 1)
        return 1 - pow(1 - borne, 1 / exposant)
    }

    // MARK: Timeline des tics

    /// Instants (en secondes depuis le départ) où le pointeur franchit une
    /// séparation entre deux segments. Sert à piloter les haptiques et le son.
    ///
    /// - Parameter maximum: nombre de tics conservés. Au-delà, on garde les
    ///   derniers, ceux qu'on entend vraiment quand la roue ralentit.
    static func instantsDesTics(plan: SpinPlan, options: [SpinOption], maximum: Int = 220) -> [Double] {
        guard options.count > 1, plan.rotationTotale > 0, plan.duree > 0 else { return [] }
        let separations = bornes(options)
        guard !separations.isEmpty else { return [] }

        let depart = plan.angleDepart
        let total = plan.rotationTotale
        var angles: [Double] = []
        angles.reserveCapacity(separations.count * Int(total / tour + 2))

        for borne in separations {
            // Franchissement quand angleRoue ≡ -borne (mod 2π).
            let premier = depart + modulo(-borne - depart, tour)
            var angle = premier
            if angle <= depart { angle += tour }
            while angle <= plan.angleArrivee {
                angles.append(angle)
                angle += tour
            }
        }

        angles.sort()
        var instants = angles.map { angle in
            plan.duree * amortissementInverse((angle - depart) / total, exposant: plan.exposant)
        }
        if instants.count > maximum {
            instants = Array(instants.suffix(maximum))
        }
        return instants
    }

    // MARK: Utilitaire

    /// Modulo toujours positif.
    static func modulo(_ valeur: Double, _ diviseur: Double) -> Double {
        let r = valeur.truncatingRemainder(dividingBy: diviseur)
        return r < 0 ? r + diviseur : r
    }

    /// Index du segment situé sous le pointeur pour un angle de roue donné.
    /// Utilisé par les tests et par l'affichage temps réel.
    static func indexSousLePointeur(angleRoue: Double, options: [SpinOption]) -> Int? {
        guard !options.isEmpty else { return nil }
        let local = modulo(-angleRoue, tour)
        let parts = spans(options)
        for (index, part) in parts.enumerated() where local >= part.debut && local < part.fin {
            return index
        }
        return parts.count - 1
    }
}
