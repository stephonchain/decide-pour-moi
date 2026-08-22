import XCTest

/// Parcours de captures pour l'App Store, piloté par `fastlane snapshot` :
/// il déroule les cinq écrans de la fiche dans la langue que fastlane
/// injecte, et produit les deux localisations en une commande.
///
/// L'état de départ est entièrement fixé par des arguments de lancement
/// (domaine d'arguments d'UserDefaults) : onboarding déjà vu, premium
/// simulé, jeu de roues de démonstration. Ces drapeaux n'existent qu'en
/// build de développement, exactement comme ces tests — et le parcours ne
/// tape jamais au clavier, ce qui l'affranchit de l'état du clavier
/// logiciel du simulateur.
@MainActor
final class CapturesTests: XCTestCase {

    /// Attente longue : la roue tourne 3 à 5 secondes, puis les confettis
    /// tombent pendant 3 secondes de plus.
    private let attenteRoue: TimeInterval = 20

    /// Rang de la roue « classe » dans la grille, fixé par `RouesDeDemo` :
    /// on la désigne par sa position, son titre changeant avec la langue.
    private let rangDeLaClasse = 1

    func testCaptures() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += [
            "-onboarding.fait", "YES",
            "-debug.premium", "YES",
            "-avis.demande", "YES",      // jamais de popup d'avis en pleine capture
            "-captures.demo", "YES"      // contenu identique dans les deux langues
        ]
        app.launch()

        // 01 — La roue d'accueil, prête à tourner
        let moyeu = attendre(app, "bouton.moyeu", "La roue d'accueil ne s'affiche pas.", timeout: 40)
        snapshot("01-Roue")

        // 02 — Le résultat, confettis compris
        moyeu.tap()
        let fermer = attendre(app, "bouton.fermerResultat", "Le résultat ne s'affiche pas.", timeout: attenteRoue)
        snapshot("02-Resultat")
        fermer.tap()
        sleep(1)

        // 03 — La grille des roues
        taper(app, "bouton.mesRoues", "Le bouton « Mes roues » est absent.")
        _ = attendre(app, "bouton.collerListe", "La grille des roues ne s'affiche pas.")
        sleep(1)                     // la feuille finit de monter
        snapshot("03-MesRoues")

        // 04 — La liste en texte brut, déjà remplie : une ligne = une option.
        // On passe par la roue de classe, celle qui a six prénoms.
        taper(app, "roue.\(rangDeLaClasse)", "La vignette de la roue de classe est absente.")
        sleep(1)                     // la feuille finit de se retirer
        taper(app, "bouton.edition", "Le bouton d'édition est absent.")
        taper(app, "bouton.listeTexte", "Le bouton de liste en texte est absent.")
        let annulerListe = attendre(app, "bouton.annulerListe", "La feuille de liste ne s'ouvre pas.")
        sleep(1)
        snapshot("04-Liste")

        // On referme la liste puis l'édition, sans rien avoir changé.
        annulerListe.tap()
        sleep(1)
        taper(app, "bouton.enregistrerRoue", "Le bouton d'enregistrement est absent.")
        sleep(1)

        // 05 — L'ordre de passage : trois tirages, le bandeau se remplit
        for _ in 0..<3 {
            taper(app, "bouton.moyeu", "Retour à la roue impossible.")
            attendre(app, "bouton.fermerResultat", "Le résultat ne s'affiche pas.", timeout: attenteRoue).tap()
            sleep(1)
        }
        snapshot("05-OrdreDePassage")
    }

    // MARK: Outils

    /// Attend une cible du parcours. Ce sont toutes des boutons ; la
    /// recherche large ne sert que de filet, au cas où SwiftUI exposerait
    /// l'une d'elles autrement.
    @discardableResult
    private func attendre(
        _ app: XCUIApplication,
        _ identifiant: String,
        _ description: String,
        timeout: TimeInterval = 15
    ) -> XCUIElement {
        let bouton = app.buttons[identifiant]
        if bouton.waitForExistence(timeout: timeout) { return bouton }

        let large = app.descendants(matching: .any).matching(identifier: identifiant).firstMatch
        XCTAssertTrue(large.waitForExistence(timeout: 5), description)
        return large
    }

    /// Tape sur une cible, en faisant défiler si besoin : une liste plus
    /// longue que l'écran ne doit pas faire échouer le parcours.
    private func taper(_ app: XCUIApplication, _ identifiant: String, _ description: String) {
        let cible = attendre(app, identifiant, description)
        var essais = 0
        while !cible.isHittable && essais < 3 {
            app.swipeUp()
            essais += 1
        }
        cible.tap()
    }
}
