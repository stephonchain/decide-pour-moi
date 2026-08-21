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

    /// Identifiant de l'entitlement, défini dans `Studio`.
    static var entitlement: String { Studio.entitlementPremium }

    enum Source: Equatable {
        case revenueCat
        case storeKit
    }

    private(set) var source: Source = .storeKit
    private(set) var estPremium = false
    /// Identifiant du produit qui accorde premium, quand il est connu.
    private(set) var produitPremium: String?
    /// Vrai tant qu'un abonnement court — y compris doublé par l'achat à vie.
    private(set) var abonnementActif = false
    private(set) var offres: [OffrePremium] = []
    private(set) var demarre = false
    private(set) var chargementEnCours = false
    /// Dernière erreur de chargement des offres, affichée au paywall.
    private(set) var erreurOffre: String?

    /// Offering courant, nécessaire au paywall distant de RevenueCat.
    private(set) var offreRevenueCat: Offering?
    private let storeKit = AchatsStoreKit()

    private init() {}

    /// Source réellement utilisée. En développement, un réglage permet de la
    /// forcer : c'est le seul moyen de tester le paywall avec le fichier
    /// StoreKit local tant que les produits ne sont pas validés côté Apple
    /// ni l'offering configuré côté RevenueCat.
    private var sourceRetenue: Source {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: CleReglage.debugSourceAchats) {
        case "storekit": return .storeKit
        case "revenuecat": return .revenueCat
        default: break
        }
        #endif
        return Studio.revenueCatConfigure ? .revenueCat : .storeKit
    }

    /// Vrai quand les outils RevenueCat — paywall distant, Customer Center —
    /// sont utilisables.
    var outilsRevenueCatDisponibles: Bool { source == .revenueCat && demarre }

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

        if sourceRetenue == .revenueCat {
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
                self.produitPremium = self.storeKit.produitPremium
                self.abonnementActif = self.storeKit.abonnementActif
            }
            storeKit.demarrer()
        }

        Task { await chargerOffre() }
    }

    func chargerOffre() async {
        erreurOffre = nil
        chargementEnCours = true
        defer { chargementEnCours = false }
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
                produitPremium = storeKit.produitPremium
                abonnementActif = storeKit.abonnementActif
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
            produitPremium = storeKit.produitPremium
            abonnementActif = storeKit.abonnementActif
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
            produitPremium = storeKit.produitPremium
            abonnementActif = storeKit.abonnementActif
        }
        return estPremium
    }

    // MARK: Interne

    private func appliquer(_ info: CustomerInfo) {
        let droit = info.entitlements[Self.entitlement]
        estPremium = droit?.isActive == true
        produitPremium = droit?.isActive == true ? droit?.productIdentifier : nil
        abonnementActif = !info.activeSubscriptions.isEmpty
        journaliserLesEntitlements(info)
    }

    /// Vrai quand premium vient de l'achat à vie : plus rien à proposer.
    /// Faux quand il vient d'un abonnement — le passage à l'achat à vie
    /// reste alors pertinent.
    var premiumEstAVie: Bool {
        produitPremium == OffrePremium.Sorte.aVie.identifiantProduit
    }

    /// Un identifiant d'entitlement mal orthographié ne produit aucune erreur :
    /// simplement un premium qui ne se déverrouille jamais. On rend donc
    /// l'écart visible dès le premier lancement en développement.
    private func journaliserLesEntitlements(_ info: CustomerInfo) {
        #if DEBUG
        let actifs = info.entitlements.active.keys.sorted()
        if !actifs.isEmpty, !actifs.contains(Self.entitlement) {
            print("""
            [RevenueCat] Entitlement « \(Self.entitlement) » introuvable.
            Entitlements actifs reçus : \(actifs.joined(separator: ", ")).
            Corrigez Studio.entitlementPremium avec l'identifiant exact.
            """)
        }
        #endif
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
