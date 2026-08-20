import Foundation
import SwiftUI

struct ReglagesView: View {

    @AppStorage(CleReglage.son) private var son = Reglages.sonParDefaut
    @AppStorage(CleReglage.confettis) private var confettis = Reglages.confettisParDefaut
    @AppStorage(CleReglage.paletteParDefaut) private var paletteParDefaut = 0
    @AppStorage(CleReglage.langue) private var langue = Langue.systeme.rawValue
    @State private var confidentialiteAffichee = false
    @State private var premium = PremiumManager.shared
    @State private var paywallAffiche = false
    @State private var onboardingRevisite = false
    @State private var messageRestauration: String? = nil
    #if DEBUG
    @AppStorage(CleReglage.debugPremium) private var debugPremium = false
    #endif

    var body: some View {
        FeuilleSombre(titre: tr("Réglages")) {
            List {
                Section {
                    if premium.estPremiumEffectif {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(Color(hex: 0xFFD53E))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("Premium actif"))
                                    .font(.system(.body, design: .rounded, weight: .bold))
                                Text(tr("Merci de soutenir une app sans pub."))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .listRowBackground(Fond.carte)
                    } else {
                        Button {
                            paywallAffiche = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(Color(hex: 0xFFD53E))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tr("Passer en premium"))
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                    Text(tr("Roues illimitées, tous les modes, historique."))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .listRowBackground(Fond.carte)

                        Button {
                            restaurer()
                        } label: {
                            Label(tr("Restaurer mes achats"), systemImage: "arrow.clockwise.circle")
                        }
                        .listRowBackground(Fond.carte)
                    }

                    if let messageRestauration {
                        Text(messageRestauration)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .listRowBackground(Fond.carte)
                    }
                } header: {
                    Text(verbatim: "Premium")
                }

                Section {
                    Toggle(isOn: $son) {
                        Label(tr("Son des tics"), systemImage: "speaker.wave.2.fill")
                    }
                    .listRowBackground(Fond.carte)

                    Toggle(isOn: $confettis) {
                        Label(tr("Confettis au résultat"), systemImage: "sparkles")
                    }
                    .listRowBackground(Fond.carte)
                } header: {
                    Text(tr("Sensations"))
                } footer: {
                    Text(tr("Les vibrations suivent le réglage système de l'iPhone."))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Section {
                    ForEach(Langue.allCases) { proposition in
                        Button {
                            Langues.choisir(proposition)
                            langue = proposition.rawValue
                            Haptiques.shared.selection()
                        } label: {
                            HStack {
                                Text(proposition.nomAffiche)
                                    .font(.system(.body, design: .rounded))
                                Spacer()
                                if langue == proposition.rawValue {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.bold)
                                }
                            }
                        }
                        .listRowBackground(Fond.carte)
                    }
                } header: {
                    Text(tr("Langue"))
                } footer: {
                    Text(tr("Ce réglage ne concerne que cette app. Vos roues gardent le texte que vous avez saisi."))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Section {
                    ChoixDePalette(paletteID: $paletteParDefaut)
                        .listRowBackground(Fond.carte)
                } header: {
                    Text(tr("Palette des nouvelles roues"))
                }

                SectionsNosApps()

                Section {
                    Button {
                        onboardingRevisite = true
                    } label: {
                        Label(tr("Revoir la présentation"), systemImage: "play.rectangle.fill")
                    }
                    .listRowBackground(Fond.carte)

                    Button {
                        confidentialiteAffichee = true
                    } label: {
                        Label(tr("Confidentialité"), systemImage: "hand.raised.fill")
                    }
                    .listRowBackground(Fond.carte)

                    if let contact = Studio.lienDeContact {
                        Link(destination: contact) {
                            Label(tr("Nous écrire"), systemImage: "envelope.fill")
                        }
                        .listRowBackground(Fond.carte)
                    }

                    HStack {
                        Label(tr("Version"), systemImage: "info.circle")
                        Spacer()
                        Text(Studio.versionAffichee)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .listRowBackground(Fond.carte)
                } header: {
                    Text(tr("À propos"))
                } footer: {
                    Text(tr("Décide pour moi fonctionne sans compte et sans publicité tierce. Vos roues et vos tirages restent sur votre iPhone."))
                        .foregroundStyle(.white.opacity(0.5))
                }

                #if DEBUG
                Section {
                    Toggle(isOn: $debugPremium) {
                        Label {
                            Text(verbatim: "Simuler premium")
                        } icon: {
                            Image(systemName: "wrench.and.screwdriver")
                        }
                    }
                    .listRowBackground(Fond.carte)
                } header: {
                    Text(verbatim: "Debug")
                } footer: {
                    Text(verbatim: "Visible uniquement en build de développement.")
                        .foregroundStyle(.white.opacity(0.5))
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(.white)
            .tint(.white)
        }
        .sheet(isPresented: $confidentialiteAffichee) {
            ConfidentialiteView()
        }
        .sheet(isPresented: $paywallAffiche) {
            PaywallView(contexte: .reglages)
        }
        .fullScreenCover(isPresented: $onboardingRevisite) {
            OnboardingFlow(estUneRevisite: true) {
                onboardingRevisite = false
            }
        }
    }

    private func restaurer() {
        messageRestauration = nil
        Task {
            do {
                messageRestauration = try await premium.restaurer()
                    ? tr("Premium restauré. Merci !")
                    : tr("Aucun achat à restaurer sur ce compte.")
            } catch {
                messageRestauration = error.localizedDescription
            }
        }
    }
}

/// Politique de confidentialité lisible hors ligne. Elle tient en quelques
/// lignes parce qu'il n'y a réellement rien à déclarer.
struct ConfidentialiteView: View {
    var body: some View {
        FeuilleSombre(titre: tr("Confidentialité")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(tr("Vos données restent chez vous"))
                        .font(.system(.title3, design: .rounded, weight: .bold))

                    Text(tr("Vos roues, vos options et votre historique de tirages restent sur votre iPhone. Ils ne sont envoyés nulle part et ne sont accessibles à personne d'autre que vous."))

                    Text(tr("Pas de compte, pas de traceur"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(tr("L'app ne demande aucune inscription, n'utilise aucun outil de mesure d'audience et n'intègre aucune régie publicitaire tierce."))

                    Text(tr("Les achats"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(tr("Les achats passent par l'App Store et par RevenueCat, notre prestataire de gestion des reçus. Il traite un identifiant anonyme et l'historique d'achat de l'app, sans lien avec votre identité. Aucune autre donnée ne lui est transmise."))

                    Text(tr("Les liens vers nos autres apps"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(tr("La section « Nos autres apps » est une liste embarquée dans l'application. Ouvrir un de ces liens vous emmène sur l'App Store, où les règles d'Apple s'appliquent."))

                    Text(tr("Suppression"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(tr("Supprimer l'application efface toutes les données qu'elle contient. L'historique de chaque roue peut aussi être effacé à tout moment."))

                    Link(destination: Studio.urlConfidentialite) {
                        Label(tr("Version en ligne"), systemImage: "arrow.up.forward")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .padding(.top, 6)
                }
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
    }
}
