import Foundation
import StoreKit
import SwiftUI

/// Demande d'avis App Store, déclenchée au 5ᵉ tirage réparti sur 2 jours
/// distincts. Une seule fois, et jamais au milieu d'une animation.
@MainActor
enum DemandeDAvis {

    /// Appelée à chaque tirage terminé. Ne fait rien tant que les conditions
    /// ne sont pas réunies.
    static func apresUnTirage(_ demander: RequestReviewAction) {
        guard Reglages.enregistrerTirageEtEvaluerAvis() else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            demander()
        }
    }
}
