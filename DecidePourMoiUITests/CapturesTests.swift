import XCTest

/// Parcours de captures pour l'App Store, piloté par `fastlane snapshot` :
/// il déroule les six écrans de la fiche dans la langue que fastlane injecte,
/// et produit les captures des deux localisations en une commande.
///
/// L'état de départ est fixé par des arguments de lancement (domaine
/// d'arguments d'UserDefaults) : onboarding déjà vu, premium simulé — les
/// deux drapeaux debug n'existant qu'en build de développement, exactement
/// comme ces tests.
///
/// La classe est isolée sur l'acteur principal : `setupSnapshot` et
/// `snapshot` le sont depuis les versions récentes de fastlane.
@MainActor
final class CapturesTests: XCTestCase {

    /// Attente longue : la roue tourne 3 à 5 secondes.
    private let attenteRoue: TimeInterval = 10

    private func lancer(premium: Bool) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += [
            "-onboarding.fait", "YES",
            "-debug.premium", premium ? "YES" : "NO",
            "-avis.demande", "YES"          // jamais de popup d'avis en pleine capture
        ]
        app.launch()
        return app
    }

    /// Langue réellement injectée par fastlane, lue dans les arguments que
    /// `setupSnapshot` vient d'ajouter — le helper n'expose plus de variable
    /// globale pour cela.
    private func langueEstFrancaise(_ app: XCUIApplication) -> Bool {
        guard
            let position = app.launchArguments.firstIndex(of: "-AppleLanguages"),
            app.launchArguments.indices.contains(position + 1)
        else { return true }
        return app.launchArguments[position + 1].contains("fr")
    }

    func testCaptures() throws {
        let app = lancer(premium: true)
        let enFrancais = langueEstFrancaise(app)

        // 01 — La roue principale, prête à tourner
        let moyeu = app.buttons["bouton.moyeu"]
        XCTAssertTrue(moyeu.waitForExistence(timeout: 15))
        snapshot("01-Roue")

        // 02 — Le résultat, confettis compris
        moyeu.tap()
        let fermerResultat = app.buttons["bouton.fermerResultat"]
        XCTAssertTrue(fermerResultat.waitForExistence(timeout: attenteRoue))
        snapshot("02-Resultat")
        fermerResultat.tap()

        // 04 — La grille des roues
        app.buttons["bouton.mesRoues"].tap()
        let collerListe = app.buttons["bouton.collerListe"]
        XCTAssertTrue(collerListe.waitForExistence(timeout: 5))
        snapshot("04-MesRoues")

        // 03 — Collage d'une liste d'élèves
        collerListe.tap()
        let champTitre = app.textFields["champ.titreListe"]
        XCTAssertTrue(champTitre.waitForExistence(timeout: 5))
        champTitre.tap()
        champTitre.typeText(enFrancais ? "La classe" : "The class")
        let champListe = app.textViews["champ.listeOptions"]
        champListe.tap()
        champListe.typeText("Lea\nMarco\nAicha\nTom\nNina\nSacha")
        snapshot("03-CollerListe")
        app.buttons["bouton.creerListe"].tap()

        // 05 — Le mode ordre de passage : on le choisit, on tire une fois,
        // le bandeau ordonné apparaît sous la roue.
        let edition = app.buttons["bouton.edition"]
        XCTAssertTrue(edition.waitForExistence(timeout: 10))
        edition.tap()
        let modeOrdre = app.buttons["mode.ordreDePassage"]
        XCTAssertTrue(modeOrdre.waitForExistence(timeout: 5))
        modeOrdre.tap()
        app.buttons["bouton.enregistrerRoue"].tap()

        XCTAssertTrue(moyeu.waitForExistence(timeout: 10))
        moyeu.tap()
        XCTAssertTrue(fermerResultat.waitForExistence(timeout: attenteRoue))
        fermerResultat.tap()
        sleep(1)
        snapshot("05-OrdreDePassage")
    }

    func testCapturePaywall() throws {
        let app = lancer(premium: false)

        // 06 — Le paywall, offres chargées depuis le fichier StoreKit local
        let reglages = app.buttons["bouton.reglages"]
        XCTAssertTrue(reglages.waitForExistence(timeout: 15))
        reglages.tap()
        let premium = app.buttons["bouton.premium"]
        XCTAssertTrue(premium.waitForExistence(timeout: 5))
        premium.tap()
        // Le temps que les offres arrivent du fichier StoreKit
        sleep(3)
        snapshot("06-Paywall")
    }
}
