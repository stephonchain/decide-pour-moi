import Foundation
import SwiftUI

/// Confettis maison : un `Canvas` piloté par `TimelineView`, aucune dépendance.
/// Les trajectoires sont tirées une fois par salve, puis simplement évaluées.
struct Confettis: View {

    /// Change de valeur à chaque résultat : relance une salve.
    let declencheur: Int
    let couleurs: [Color]

    private static let nombre = 90
    private static let duree: Double = 3.2

    @State private var salve: [Particule] = []
    @State private var debut = Date.now
    /// L'horloge ne tourne que pendant la salve. Sans cela, `TimelineView`
    /// continue de réveiller le rendu à chaque image pour dessiner du vide :
    /// batterie gaspillée, et une app que le système ne voit plus jamais au
    /// repos — ce qui bloque aussi les tests d'interface.
    @State private var enCours = false

    var body: some View {
        TimelineView(.animation(paused: !enCours)) { contexte in
            Canvas { dessin, taille in
                let temps = contexte.date.timeIntervalSince(debut)
                guard temps < Self.duree else { return }
                for particule in salve {
                    dessiner(particule, temps: temps, dans: &dessin, taille: taille)
                }
            }
        }
        .task(id: declencheur) {
            debut = .now
            salve = (0..<Self.nombre).map { _ in Particule.aleatoire(couleurs: couleurs) }
            enCours = true
            // Annulée si la vue disparaît avant la fin : rien à nettoyer,
            // elle emporte son état avec elle.
            guard (try? await Task.sleep(for: .seconds(Self.duree))) != nil else { return }
            salve = []
            enCours = false
        }
    }

    private func dessiner(_ particule: Particule, temps: Double, dans dessin: inout GraphicsContext, taille: CGSize) {
        let vie = temps - particule.retard
        guard vie > 0 else { return }

        // Toute la physique se calcule en `Double` : mélanger `Double` et
        // `CGFloat` dans une même expression rend les appels ambigus.
        let largeur = Double(taille.width)
        let hauteur = Double(taille.height)

        // Chute avec gravité, dérive horizontale et léger balancement.
        let x: Double = particule.xDepart * largeur
            + particule.deriveX * vie * largeur * 0.12
            + sin(vie * particule.frequence + particule.phase) * 14
        let y: Double = -40 + particule.vitesseY * vie * hauteur * 0.30
            + 0.5 * 340 * vie * vie
        guard y < hauteur + 40 else { return }

        let opacite = max(0, min(1, (Self.duree - temps) / 0.9))
        var local = dessin
        local.translateBy(x: CGFloat(x), y: CGFloat(y))
        local.rotate(by: .radians(particule.rotation + vie * particule.vitesseRotation))
        local.opacity = opacite
        local.fill(
            Path(roundedRect: CGRect(x: -particule.largeur / 2, y: -particule.hauteur / 2,
                                     width: particule.largeur, height: particule.hauteur),
                 cornerRadius: 1.5),
            with: .color(particule.couleur)
        )
    }

    struct Particule {
        let xDepart: Double
        let deriveX: Double
        let vitesseY: Double
        let retard: Double
        let rotation: Double
        let vitesseRotation: Double
        let frequence: Double
        let phase: Double
        let largeur: Double
        let hauteur: Double
        let couleur: Color

        static func aleatoire(couleurs: [Color]) -> Particule {
            let palette = couleurs.isEmpty ? [Color.white] : couleurs
            return Particule(
                xDepart: .random(in: 0...1),
                deriveX: .random(in: -1...1),
                vitesseY: .random(in: 0.2...1.1),
                retard: .random(in: 0...0.45),
                rotation: .random(in: 0...(2 * .pi)),
                vitesseRotation: .random(in: -7...7),
                frequence: .random(in: 3...7),
                phase: .random(in: 0...(2 * .pi)),
                largeur: .random(in: 6...11),
                hauteur: .random(in: 9...16),
                couleur: palette.randomElement() ?? .white
            )
        }
    }
}
