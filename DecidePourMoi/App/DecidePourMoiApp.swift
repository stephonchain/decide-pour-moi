import SwiftData
import SwiftUI

@main
struct DecidePourMoiApp: App {

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
    }

    var body: some Scene {
        WindowGroup {
            RacineView()
                .preferredColorScheme(.dark)
                .tint(.white)
        }
        .modelContainer(conteneur)
    }
}
