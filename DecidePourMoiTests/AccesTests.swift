import Foundation
import Testing
@testable import DecidePourMoi

/// La matrice gratuit / premium / historique, règle par règle.
@Suite("Matrice d'accès")
struct AccesTests {

    private let gratuit = Acces(estPremium: false, estHistorique: false)
    private let premium = Acces(estPremium: true, estHistorique: false)
    private let historique = Acces(estPremium: false, estHistorique: true)

    @Test("Le gratuit garde le tirage avec remise, et seulement lui")
    func modesGratuits() {
        #expect(gratuit.modeAutorise(.avecRemise))
        #expect(!gratuit.modeAutorise(.sansRemise))
        #expect(!gratuit.modeAutorise(.ordreDePassage))
        #expect(!gratuit.retraitAutorise)
    }

    @Test("Le premium débloque tous les modes")
    func modesPremium() {
        for mode in ModeTirage.allCases {
            #expect(premium.modeAutorise(mode))
        }
        #expect(premium.retraitAutorise)
    }

    @Test("L'utilisateur historique garde tout ce qui lui a été donné")
    func acquisHistorique() {
        for mode in ModeTirage.allCases {
            #expect(historique.modeAutorise(mode))
        }
        #expect(historique.ponderationAutorisee)
        #expect(historique.historiqueAutorise)
        #expect(historique.retraitAutorise)
        #expect(historique.paletteAutorisee(5))
    }

    @Test("La pondération et l'historique sont premium")
    func fonctionsPremium() {
        #expect(!gratuit.ponderationAutorisee)
        #expect(!gratuit.historiqueAutorise)
        #expect(premium.ponderationAutorisee)
        #expect(premium.historiqueAutorise)
    }

    @Test("Deux palettes gratuites, six en premium")
    func palettes() {
        #expect(gratuit.palettesAutorisees == Acces.palettesGratuites)
        #expect(gratuit.palettesAutorisees.count == 2)
        #expect(premium.palettesAutorisees.count == Palette.toutes.count)
        for id in Acces.palettesGratuites {
            #expect(gratuit.paletteAutorisee(id))
        }
        #expect(!gratuit.paletteAutorisee(2))
    }

    @Test("La création s'arrête à une roue déverrouillée en gratuit")
    func creation() {
        #expect(gratuit.peutCreerRoue(rouesDeverrouillees: 0))
        #expect(!gratuit.peutCreerRoue(rouesDeverrouillees: 1))
        #expect(!gratuit.peutCreerRoue(rouesDeverrouillees: 4))
        #expect(premium.peutCreerRoue(rouesDeverrouillees: 40))
        // Historique : ses roues existantes le placent au-dessus de la
        // limite, mais s'il les supprime toutes il peut en recréer une.
        #expect(!historique.peutCreerRoue(rouesDeverrouillees: 3))
        #expect(historique.peutCreerRoue(rouesDeverrouillees: 0))
    }

    @Test("Une roue verrouillée ne s'ouvre qu'en premium")
    func ouverture() {
        let teaser = Roue(titre: "Teaser")
        teaser.verrouillee = true
        let libre = Roue(titre: "Libre")

        #expect(!gratuit.peutOuvrir(teaser))
        #expect(gratuit.peutOuvrir(libre))
        #expect(premium.peutOuvrir(teaser))
        // Les roues d'un utilisateur historique ne sont jamais verrouillées ;
        // s'il en existait une, la règle premium s'appliquerait.
        #expect(!historique.peutOuvrir(teaser))
        #expect(historique.peutOuvrir(libre))
    }

    @Test("Trois modifications offertes en gratuit, puis le verrou")
    func modificationsGratuites() {
        #expect(gratuit.droitDEdition(roueFigee: false, modificationsUtilisees: 0) == .limite(restantes: 3))
        #expect(gratuit.droitDEdition(roueFigee: false, modificationsUtilisees: 2) == .limite(restantes: 1))
        #expect(gratuit.droitDEdition(roueFigee: false, modificationsUtilisees: 3) == .bloque)
        // Un compteur corrompu ou dépassé ne doit jamais rouvrir l'édition.
        #expect(gratuit.droitDEdition(roueFigee: false, modificationsUtilisees: 99) == .bloque)
    }

    @Test("La roue figée ne se modifie qu'en premium")
    func roueFigee() {
        #expect(gratuit.droitDEdition(roueFigee: true, modificationsUtilisees: 0) == .bloque)
        #expect(premium.droitDEdition(roueFigee: true, modificationsUtilisees: 0) == .libre)
    }

    @Test("Premium et historique modifient sans limite")
    func editionLibre() {
        #expect(premium.droitDEdition(roueFigee: false, modificationsUtilisees: 50) == .libre)
        // Ce qui a été donné ne se reprend pas : l'historique modifiait
        // librement avant le freemium, il continue.
        #expect(historique.droitDEdition(roueFigee: false, modificationsUtilisees: 50) == .libre)
        #expect(historique.droitDEdition(roueFigee: true, modificationsUtilisees: 0) == .libre)
    }
}
