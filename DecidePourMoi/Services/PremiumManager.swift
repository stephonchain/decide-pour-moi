import Foundation
import RevenueCat
import SwiftUI

/// Pont unique vers RevenueCat. Tout le gating de l'app teste `estPremium`,
/// jamais un identifiant de produit : c'est l'entitlement `premium` qui fait
/// foi, quel que soit le produit qui l'a accordé.
@MainActor
@Observable
final class PremiumManager {

    static let shared = PremiumManager()

    /// Nom de l'entitlement dans le dashboard RevenueCat.
    static let entitlement = "premium"

    private(set) var estPremium = false
    private(set) var offre: Offering?
    private(set) var configure = false
    /// Dernière erreur de chargement de l'offre, pour l'afficher au paywall.
    private(set) var erreurOffre: String?

    private init() {}

    /// Accès courant, à passer aux vues.
    var acces: Acces {
        Acces(estPremium: estPremiumEffectif, estHistorique: Reglages.utilisateurHistorique)
    }

    /// En DEBUG, un réglage local permet de simuler premium pour tester le
    /// gating sans compte RevenueCat ni sandbox.
    var estPremiumEffectif: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: CleReglage.debugPremium) { return true }
        #endif
        return estPremium
    }

    // MARK: Configuration

    /// À appeler une fois au lancement. Sans clé renseignée, l'app reste
    /// pleinement fonctionnelle en gratuit : rien ne doit casser.
    func configurer() {
        guard !configure, !Studio.cleRevenueCat.contains("REMPLACER") else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Studio.cleRevenueCat)
        configure = true

        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.appliquer(info)
            }
        }
        Task { await chargerOffre() }
    }

    func chargerOffre() async {
        guard configure else { return }
        erreurOffre = nil
        do {
            offre = try await Purchases.shared.offerings().current
            if offre == nil {
                erreurOffre = tr("Aucune offre disponible pour le moment.")
            }
        } catch {
            erreurOffre = error.localizedDescription
        }
    }

    private func appliquer(_ info: CustomerInfo) {
        estPremium = info.entitlements[Self.entitlement]?.isActive == true
    }

    // MARK: Achats

    enum ResultatAchat {
        case achete
        case annule
    }

    func acheter(_ package: Package) async throws -> ResultatAchat {
        let resultat = try await Purchases.shared.purchase(package: package)
        appliquer(resultat.customerInfo)
        return resultat.userCancelled ? .annule : .achete
    }

    /// Restaure les achats. Retourne vrai si premium est actif à l'issue.
    func restaurer() async throws -> Bool {
        let info = try await Purchases.shared.restorePurchases()
        appliquer(info)
        return estPremium
    }

    // MARK: Lecture de l'offre

    var packageHebdo: Package? { offre?.weekly }
    var packageMensuel: Package? { offre?.monthly }
    var packageAVie: Package? { offre?.lifetime }

    /// Vrai si le mensuel porte bien son offre d'introduction (l'essai de
    /// 3 jours se configure dans App Store Connect, pas dans le code).
    var essaiDisponible: Bool {
        packageMensuel?.storeProduct.introductoryDiscount != nil
    }
}
