import Foundation
import StoreKit

/// Achats en direct via StoreKit 2, sans intermédiaire.
///
/// Sert tant que la clé RevenueCat n'est pas renseignée : le paywall est
/// alors pleinement testable avec le fichier `DecidePourMoi.storekit` ou en
/// sandbox, dès que les produits existent dans App Store Connect.
/// Une fois la clé en place, c'est RevenueCat qui prend le relais.
@MainActor
final class AchatsStoreKit {

    private(set) var produits: [OffrePremium.Sorte: Product] = [:]
    private(set) var estPremium = false
    /// Identifiant du produit qui accorde premium ; l'achat à vie prime
    /// quand plusieurs droits coexistent.
    private(set) var produitPremium: String?
    /// Vrai tant qu'un abonnement court, même si l'achat à vie le double.
    private(set) var abonnementActif = false

    /// Prévenu à chaque changement de droits, y compris ceux qui n'ont pas
    /// été déclenchés depuis le paywall : approbation parentale, achat fait
    /// sur un autre appareil, remboursement, renouvellement.
    var surChangementDEtat: (() -> Void)?

    private var veille: Task<Void, Never>?

    /// Démarre l'écoute des transactions. À appeler une fois.
    func demarrer() {
        guard veille == nil else { return }
        veille = Task { [weak self] in
            // Les achats faits ailleurs (autre appareil, remboursement,
            // renouvellement) arrivent par ici.
            for await resultat in Transaction.updates {
                guard let transaction = try? Self.verifier(resultat) else { continue }
                await transaction.finish()
                await self?.rafraichirLEtat()
            }
        }
    }

    /// Charge les produits et l'état courant. Lève si le store est injoignable.
    func charger() async throws {
        let identifiants = OffrePremium.Sorte.allCases.map(\.identifiantProduit)
        let charges = try await Product.products(for: identifiants)

        var parSorte: [OffrePremium.Sorte: Product] = [:]
        for sorte in OffrePremium.Sorte.allCases {
            parSorte[sorte] = charges.first { $0.id == sorte.identifiantProduit }
        }
        produits = parSorte
        await rafraichirLEtat()
    }

    var offres: [OffrePremium] {
        OffrePremium.Sorte.ordreDAffichage.compactMap { sorte in
            guard let produit = produits[sorte] else { return nil }
            return OffrePremium(
                sorte: sorte,
                prixAffiche: produit.displayPrice,
                aUnEssai: produit.subscription?.introductoryOffer != nil
            )
        }
    }

    /// - Returns: vrai si l'achat a abouti, faux s'il a été annulé ou reste
    ///   en attente (validation parentale, par exemple).
    func acheter(_ sorte: OffrePremium.Sorte) async throws -> Bool {
        guard let produit = produits[sorte] else { return false }
        switch try await produit.purchase() {
        case .success(let resultat):
            let transaction = try Self.verifier(resultat)
            await transaction.finish()
            await rafraichirLEtat()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restaurer() async throws -> Bool {
        try await AppStore.sync()
        await rafraichirLEtat()
        return estPremium
    }

    /// Premium est actif si l'un des trois produits figure dans les droits
    /// courants. StoreKit exclut déjà les abonnements expirés.
    private func rafraichirLEtat() async {
        let identifiants = Set(OffrePremium.Sorte.allCases.map(\.identifiantProduit))
        var accordes: [String] = []
        for await resultat in Transaction.currentEntitlements {
            guard
                let transaction = try? Self.verifier(resultat),
                identifiants.contains(transaction.productID),
                transaction.revocationDate == nil
            else { continue }
            accordes.append(transaction.productID)
        }
        let aVie = OffrePremium.Sorte.aVie.identifiantProduit
        let produit = accordes.contains(aVie) ? aVie : accordes.first
        let actif = !accordes.isEmpty
        let abonnement = accordes.contains { $0 != aVie }
        guard actif != estPremium || produit != produitPremium || abonnement != abonnementActif else { return }
        estPremium = actif
        produitPremium = produit
        abonnementActif = abonnement
        surChangementDEtat?()
    }

    private static func verifier(_ resultat: VerificationResult<Transaction>) throws -> Transaction {
        switch resultat {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let erreur):
            throw erreur
        }
    }
}
