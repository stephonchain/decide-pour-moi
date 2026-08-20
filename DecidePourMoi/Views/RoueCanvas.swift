import Foundation
import SwiftUI

/// Segment tel que la roue le dessine : une valeur simple, découplée de
/// SwiftData pour que `Canvas` ne redessine que sur un vrai changement.
struct SegmentAffichage: Equatable, Identifiable, Hashable {
    let id: UUID
    let label: String
    let poids: Int
}

/// Rendu de la roue. Uniquement le disque : le moyeu et le pointeur sont
/// posés par-dessus et ne tournent pas.
struct RoueCanvas: View {

    let segments: [SegmentAffichage]
    let palette: Palette

    /// Au-delà de ce nombre de segments, les libellés deviennent illisibles :
    /// on les masque sur la roue, ils restent visibles au résultat.
    static let seuilAffichageLibelles = 20

    /// Longueur au-delà de laquelle on tronque proprement.
    static let longueurMaxLibelle = 20

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { contexte, taille in
            let rayon = min(taille.width, taille.height) / 2
            let centre = CGPoint(x: taille.width / 2, y: taille.height / 2)
            guard rayon > 0, !segments.isEmpty else { return }

            let options = segments.map { SpinOption(id: $0.id, poids: $0.poids) }
            let parts = SpinEngine.spans(options)

            dessinerSegments(contexte: contexte, centre: centre, rayon: rayon, parts: parts)
            dessinerSeparations(contexte: contexte, centre: centre, rayon: rayon, parts: parts)
            dessinerCercle(contexte: contexte, centre: centre, rayon: rayon)

            if segments.count <= Self.seuilAffichageLibelles {
                dessinerLibelles(contexte: contexte, centre: centre, rayon: rayon, parts: parts)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Tracés

    private func dessinerSegments(contexte: GraphicsContext, centre: CGPoint, rayon: CGFloat, parts: [SpanAngulaire]) {
        for (index, part) in parts.enumerated() {
            var trace = Path()
            trace.move(to: centre)
            trace.addArc(
                center: centre,
                radius: rayon,
                startAngle: .radians(part.debut - .pi / 2),
                endAngle: .radians(part.fin - .pi / 2),
                clockwise: false
            )
            trace.closeSubpath()
            contexte.fill(trace, with: .color(palette.couleur(index: index, total: parts.count)))
        }
    }

    private func dessinerSeparations(contexte: GraphicsContext, centre: CGPoint, rayon: CGFloat, parts: [SpanAngulaire]) {
        guard parts.count > 1 else { return }
        let epaisseur = max(1, rayon * 0.008)
        var trace = Path()
        for part in parts {
            trace.move(to: centre)
            trace.addLine(to: Self.point(centre: centre, rayon: rayon, angle: part.debut - .pi / 2))
        }
        contexte.stroke(trace, with: .color(.white.opacity(0.9)), lineWidth: epaisseur)
    }

    private func dessinerCercle(contexte: GraphicsContext, centre: CGPoint, rayon: CGFloat) {
        let epaisseur = max(3, rayon * 0.035)
        let cercle = Path(ellipseIn: CGRect(
            x: centre.x - rayon + epaisseur / 2,
            y: centre.y - rayon + epaisseur / 2,
            width: (rayon - epaisseur / 2) * 2,
            height: (rayon - epaisseur / 2) * 2
        ))
        contexte.stroke(cercle, with: .color(.white), lineWidth: epaisseur)
    }

    private func dessinerLibelles(contexte: GraphicsContext, centre: CGPoint, rayon: CGFloat, parts: [SpanAngulaire]) {
        let taillePolice = tailleDePolice(rayon: rayon, parts: parts)

        for (index, part) in parts.enumerated() {
            let libelle = Self.tronquer(segments[index].label)
            guard !libelle.isEmpty else { continue }

            let couleurSegment = palette.couleur(index: index, total: parts.count)
            let couleurTexte: Color = couleurSegment.estClaire ? Color(hex: 0x1B1B33) : .white

            let texte = Text(libelle)
                .font(.system(size: taillePolice, weight: .semibold, design: .rounded))
                .foregroundStyle(couleurTexte)
            let resolu = contexte.resolve(texte)

            // Angle mathématique du centre du segment (0 rad = 3 h).
            let angle = part.centre - .pi / 2
            // Sur la moitié gauche, on retourne le texte pour qu'il reste lisible.
            let aGauche = part.centre > .pi

            var local = contexte
            local.translateBy(x: centre.x, y: centre.y)
            local.rotate(by: .radians(aGauche ? angle + .pi : angle))
            local.draw(
                resolu,
                at: CGPoint(x: aGauche ? -rayon * 0.88 : rayon * 0.88, y: 0),
                anchor: aGauche ? .leading : .trailing
            )
        }
    }

    // MARK: Mesures

    /// Point du cercle à l'angle donné. Le calcul se fait entièrement en
    /// `Double` : mélanger `Double` et `CGFloat` dans une même expression rend
    /// l'appel à `cos` ambigu.
    static func point(centre: CGPoint, rayon: CGFloat, angle: Double) -> CGPoint {
        let x: Double = Double(centre.x) + Double(rayon) * cos(angle)
        let y: Double = Double(centre.y) + Double(rayon) * sin(angle)
        return CGPoint(x: x, y: y)
    }

    private func tailleDePolice(rayon: CGFloat, parts: [SpanAngulaire]) -> CGFloat {
        // La contrainte, c'est la hauteur disponible dans le segment le plus étroit.
        let plusEtroit = parts.map(\.largeur).min() ?? SpinEngine.tour
        let hauteurDisponible = rayon * 0.72 * CGFloat(min(plusEtroit, Double.pi / 3)) * 0.9
        let longueurMax = segments.map { Self.tronquer($0.label).count }.max() ?? 1
        let largeurDisponible = rayon * 0.66 / CGFloat(max(longueurMax, 1)) * 1.85
        return min(max(min(hauteurDisponible, largeurDisponible), 9), rayon * 0.11)
    }

    static func tronquer(_ libelle: String) -> String {
        let propre = libelle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard propre.count > longueurMaxLibelle else { return propre }
        return String(propre.prefix(longueurMaxLibelle - 1)) + "…"
    }
}

/// Pointeur fixe en haut de la roue, repris de l'icône : une goutte blanche
/// dont la pointe désigne le segment gagnant.
struct PointeurRoue: View {
    var body: some View {
        GouttePointeur()
            .fill(.white)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            .accessibilityHidden(true)
    }
}

struct GouttePointeur: Shape {
    func path(in rect: CGRect) -> Path {
        let largeur = rect.width
        let rayon = largeur / 2
        let centre = CGPoint(x: rect.midX, y: rect.minY + rayon)
        let pointe = CGPoint(x: rect.midX, y: rect.maxY)

        // Tangentes du cercle passant par la pointe : la goutte se ferme sans cassure.
        let distance = Double(pointe.y - centre.y)
        guard distance > Double(rayon) else { return Path(ellipseIn: rect) }
        let angle: Double = acos(Double(rayon) / distance)

        var trace = Path()
        // On parcourt le grand arc, celui qui passe par le haut, puis on
        // redescend en ligne droite jusqu'à la pointe.
        trace.addArc(
            center: centre,
            radius: rayon,
            startAngle: .radians(.pi / 2 + angle),
            endAngle: .radians(.pi / 2 - angle + 2 * .pi),
            clockwise: false
        )
        trace.addLine(to: pointe)
        trace.closeSubpath()
        return trace
    }
}

/// Moyeu central : c'est aussi le bouton « tourner ».
struct MoyeuRoue: View {
    let enRotation: Bool
    let couleur: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            Circle()
                .fill(couleur)
                .padding(12)
            Image(systemName: enRotation ? "hourglass" : "play.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .opacity(enRotation ? 0.6 : 1)
        }
    }
}
