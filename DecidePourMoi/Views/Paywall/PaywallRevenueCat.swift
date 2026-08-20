import Foundation
import RevenueCat
import RevenueCatUI
import SwiftUI

/// Aiguillage entre les deux paywalls.
///
/// - **RevenueCat** quand le SDK pilote les achats : le visuel se conçoit
///   dans le tableau de bord et se modifie sans nouvelle version de l'app,
///   ce qui permet aussi les tests A/B.
/// - **Le paywall maison** sinon, c'est-à-dire quand les achats passent par
///   StoreKit en direct. Il reste le seul à savoir d'où vient l'utilisateur
///   et à adapter son titre en conséquence.
struct PaywallAdapte: View {

    let contexte: ContextePaywall
    var surFermeture: (() -> Void)? = nil

    @Environment(\.dismiss) private var fermerFeuille
    @State private var premium = PremiumManager.shared

    var body: some View {
        Group {
            if premium.outilsRevenueCatDisponibles, let offering = premium.offreRevenueCat {
                RevenueCatUI.PaywallView(offering: offering)
                    .onPurchaseCompleted { _ in fermer() }
                    .onRestoreCompleted { info in
                        if info.entitlements[PremiumManager.entitlement]?.isActive == true {
                            fermer()
                        }
                    }
            } else {
                PaywallMaison(contexte: contexte, surFermeture: surFermeture)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func fermer() {
        if let surFermeture {
            surFermeture()
        } else {
            fermerFeuille()
        }
    }
}

/// Espace de gestion d'abonnement fourni par RevenueCat : changement de
/// formule, annulation, demande de remboursement, historique. Tout ce qu'on
/// devrait sinon renvoyer vers les réglages système.
struct EspaceClient: View {
    var body: some View {
        CustomerCenterView()
            .preferredColorScheme(.dark)
    }
}
