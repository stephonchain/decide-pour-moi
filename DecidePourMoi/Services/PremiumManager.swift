import Foundation
import RevenueCat
import SwiftUI

/// Point d'entrée unique des achats pour toute l'app.
///
/// Deux sources possibles, choisies automatiquement :
/// - **RevenueCat** dès que la clé publique est renseignée dans `Studio`.
///   C'est la cible de production : reçus, essais et tableau de bord de
///   conversion sans rien coder côté serveur.
/// - **StoreKit en direct** tant qu'elle ne l'est pas, pour que le paywall
///   soit testable dès que les produits existent côté Apple.
///
/// Dans les deux cas le gating teste `estPremiumEffectif`, jamais un
/// identifiant de produit.
@MainActor
@Observable
final class PremiumManager {

    static let shared = PremiumManager()

    /// Nom de l'entitlement dans le tableau de bord RevenueCat.
    static let entitlement = "premium"

    enum Source: Equatable {
        case revenueCat
        case storeKit
    }

    private(set) var source: Source = .storeKit
    private(set) var estPremium = false
    private(set) var offres: [OffrePremium] = []
    private(set) var demarre = false
    /// Dernière erreur de chargement des offres, affichée au paywall.
    private(set) var erreurOffre: String?

    private var offreRevenueCat: Offering?
    private let storeKit = AchatsStoreKit()

    private init() {}

    /// Accès courant, à passer aux vues.
    var acces: Acces {
        Acces(estPremium: estPremiumEffectif, estHistorique: Reglages.utilisateurHistorique)
    }

    /// En DEBUG, un réglage local simule premium pour tester le gating sans
    /// aucun achat.
    var estPremiumEffectif: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: CleReglage.debugPremium) { return true }
        #endif
        return estPremium
    }

    // MARK: Démarrage

    /// À appeler une fois au lancement.
    func configurer() {
        guard !demarre else { return }
        demarre = true

        if Studio.revenueCatConfigure {
            source = .revenueCat
            Purchases.logLevel = .warn
            Purchases.configure(withAPIKey: Studio.cleRevenueCat)
            Task { [weak self] in
                for await info in Purchases.shared.customerInfoStream {
                    self?.appliquer(info)
                }
            }
        } else {
            source = .storeKit
            storeKit.surChangementDEtat = { [weak self] in
                guard let self else { return }
                self.estPremium = self.storeKit.estPremium
            }
            storeKit.demarrer()
        }

        Task { await chargerOffre() }
    }

    func chargerOffre() async {
        erreurOffre = nil
        do {
            switch source {
            case .revenueCat:
                offreRevenueCat = try await Purchases.shared.offerings().current
                offres = OffrePremium.Sorte.ordreDAffichage.compactMap { sorte in
                    guard let produit = packageRevenueCat(sorte)?.storeProduct else { return nil }
                    return OffrePremium(
                        sorte: sorte,
                        prixAffiche: produit.localizedPriceString,
                        aUnEssai: produit.introductoryDiscount != nil
                    )
                }
            case .storeKit:
                try await storeKit.charger()
                offres = storeKit.offres
                estPremium = storeKit.estPremium
            }
            if offres.isEmpty {
                erreurOffre = tr("Aucune offre disponible pour le moment.")
            }
        } catch {
            erreurOffre = error.localizedDescription
        }
    }

    // MARK: Achats

    enum ResultatAchat {
        case achete
        case annule
    }

    func acheter(_ sorte: OffrePremium.Sorte) async throws -> ResultatAchat {
        switch source {
        case .revenueCat:
            guard let package = packageRevenueCat(sorte) else { return .annule }
            let resultat = try await Purchases.shared.purchase(package: package)
            appliquer(resultat.customerInfo)
            return resultat.userCancelled ? .annule : .achete
        case .storeKit:
            let achete = try await storeKit.acheter(sorte)
            estPremium = storeKit.estPremium
            return achete ? .achete : .annule
        }
    }

    /// Restaure les achats. Retourne vrai si premium est actif à l'issue.
    func restaurer() async throws -> Bool {
        switch source {
        case .revenueCat:
            appliquer(try await Purchases.shared.restorePurchases())
        case .storeKit:
            _ = try await storeKit.restaurer()
            estPremium = storeKit.estPremium
        }
        return estPremium
    }

    // MARK: Interne

    private func appliquer(_ info: CustomerInfo) {
        estPremium = info.entitlements[Self.entitlement]?.isActive == true
    }

    /// Les accès `monthly`, `weekly` et `lifetime` n'existent que si les
    /// packages portent les identifiants standards de RevenueCat.
    private func packageRevenueCat(_ sorte: OffrePremium.Sorte) -> Package? {
        switch sorte {
        case .mensuel: offreRevenueCat?.monthly
        case .hebdo: offreRevenueCat?.weekly
        case .aVie: offreRevenueCat?.lifetime
        }
    }
}
