import SwiftData
import SwiftUI

@main
struct DecidePourMoiApp: App {

    /// Relit la langue choisie : en changer reconstruit toute l'interface.
    @AppStorage(CleReglage.langue) private var langue = Langue.systeme.rawValue

    private let conteneur: ModelContainer

    init() {
        let schema = Schema([Roue.self, OptionRoue.self, Tirage.self])
        do {
            conteneur = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            )
        } catch {
            // Un magasin illisible ne doit pas bloquer l'app : on repart propre.
            conteneur = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }

#if DEBUG
        // Parcours de captures : le jeu de roues est remis à neuf ici,
        // avant que la moindre vue ne tienne un modèle — la même remise à
        // neuf faite plus tard supprimerait la roue déjà affichée.
        if RouesDeDemo.demandees {
            RouesDeDemo.installer(dans: ModelContext(conteneur))
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            RacineView()
                .preferredColorScheme(.dark)
                .tint(.white)
                .environment(\.locale, Langues.locale)
                .id(langue)
                .task { PremiumManager.shared.configurer() }
        }
        .modelContainer(conteneur)
    }
}
