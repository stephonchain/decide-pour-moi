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

    /// Attente longue : la roue tourne 3 à 5 secondes.
    private let attenteRoue: TimeInterval = 15

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
        let moyeu = element(app, "bouton.moyeu")
        XCTAssertTrue(moyeu.waitForExistence(timeout: 25), "La roue d'accueil ne s'affiche pas.")
        snapshot("01-Roue")

        // 02 — Le résultat, confettis compris
        tirer(app, moyeu: moyeu)
        snapshot("02-Resultat")
        fermerLeResultat(app)

        // 03 — La grille des roues
        taper(app, "bouton.mesRoues", "Le bouton « Mes roues » est absent.")
        let collerListe = element(app, "bouton.collerListe")
        XCTAssertTrue(collerListe.waitForExistence(timeout: 10), "La grille des roues ne s'affiche pas.")
        sleep(1)                     // la feuille finit de monter
        snapshot("03-MesRoues")

        // 04 — La liste en texte brut, déjà remplie : une ligne = une option.
        // On passe par la roue de classe, celle qui a six prénoms.
        taper(app, "roue.\(rangDeLaClasse)", "La vignette de la roue de classe est absente.")
        sleep(1)                     // la feuille finit de se retirer
        taper(app, "bouton.edition", "Le bouton d'édition est absent.")
        taper(app, "bouton.listeTexte", "Le bouton de liste en texte est absent.")
        let annulerListe = element(app, "bouton.annulerListe")
        XCTAssertTrue(annulerListe.waitForExistence(timeout: 10), "La feuille de liste ne s'ouvre pas.")
        sleep(1)
        snapshot("04-Liste")

        // On referme la liste puis l'édition, sans rien avoir changé.
        annulerListe.tap()
        sleep(1)
        taper(app, "bouton.enregistrerRoue", "Le bouton d'enregistrement est absent.")
        sleep(1)

        // 05 — L'ordre de passage : trois tirages, le bandeau se remplit
        XCTAssertTrue(moyeu.waitForExistence(timeout: 15), "Retour à la roue impossible.")
        for _ in 0..<3 {
            tirer(app, moyeu: moyeu)
            fermerLeResultat(app)
        }
        snapshot("05-OrdreDePassage")
    }

    // MARK: Outils

    /// Recherche par identifiant sans présumer du type d'élément : selon
    /// la vue, SwiftUI expose un bouton, un texte ou un simple groupe.
    private func element(_ app: XCUIApplication, _ identifiant: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifiant).firstMatch
    }

    /// Tape sur un élément, en faisant défiler si besoin : une liste plus
    /// longue que l'écran ne doit pas faire échouer le parcours.
    private func taper(_ app: XCUIApplication, _ identifiant: String, _ description: String) {
        let cible = element(app, identifiant)
        XCTAssertTrue(cible.waitForExistence(timeout: 15), description)
        var essais = 0
        while !cible.isHittable && essais < 3 {
            app.swipeUp()
            essais += 1
        }
        cible.tap()
    }

    /// Lance la roue et attend la fin de l'animation.
    private func tirer(_ app: XCUIApplication, moyeu: XCUIElement) {
        moyeu.tap()
        let fermer = element(app, "bouton.fermerResultat")
        XCTAssertTrue(fermer.waitForExistence(timeout: attenteRoue), "Le résultat ne s'affiche pas.")
    }

    /// Referme le résultat et laisse l'overlay disparaître avant la suite.
    private func fermerLeResultat(_ app: XCUIApplication) {
        let fermer = element(app, "bouton.fermerResultat")
        if fermer.waitForExistence(timeout: attenteRoue) { fermer.tap() }
        sleep(1)
    }
}
