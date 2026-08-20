import Foundation
import SwiftUI

struct ReglagesView: View {

    @AppStorage(CleReglage.son) private var son = Reglages.sonParDefaut
    @AppStorage(CleReglage.confettis) private var confettis = Reglages.confettisParDefaut
    @AppStorage(CleReglage.paletteParDefaut) private var paletteParDefaut = 0
    @State private var confidentialiteAffichee = false

    var body: some View {
        FeuilleSombre(titre: "Réglages") {
            List {
                Section {
                    Toggle(isOn: $son) {
                        Label("Son des tics", systemImage: "speaker.wave.2.fill")
                    }
                    .listRowBackground(Fond.carte)

                    Toggle(isOn: $confettis) {
                        Label("Confettis au résultat", systemImage: "sparkles")
                    }
                    .listRowBackground(Fond.carte)
                } header: {
                    Text("Sensations")
                } footer: {
                    Text("Les vibrations suivent le réglage système de l'iPhone.")
                        .foregroundStyle(.white.opacity(0.5))
                }

                Section {
                    ChoixDePalette(paletteID: $paletteParDefaut)
                        .listRowBackground(Fond.carte)
                } header: {
                    Text("Palette des nouvelles roues")
                }

                SectionsNosApps()

                Section {
                    Button {
                        confidentialiteAffichee = true
                    } label: {
                        Label("Confidentialité", systemImage: "hand.raised.fill")
                    }
                    .listRowBackground(Fond.carte)

                    if let contact = Studio.lienDeContact {
                        Link(destination: contact) {
                            Label("Nous écrire", systemImage: "envelope.fill")
                        }
                        .listRowBackground(Fond.carte)
                    }

                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(Studio.versionAffichee)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .listRowBackground(Fond.carte)
                } header: {
                    Text("À propos")
                } footer: {
                    Text("Décide pour moi fonctionne entièrement hors ligne. Aucune donnée n'est collectée, aucun compte n'est nécessaire.")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(.white)
            .tint(.white)
        }
        .sheet(isPresented: $confidentialiteAffichee) {
            ConfidentialiteView()
        }
    }
}

/// Politique de confidentialité lisible hors ligne. Elle tient en quelques
/// lignes parce qu'il n'y a réellement rien à déclarer.
struct ConfidentialiteView: View {
    var body: some View {
        FeuilleSombre(titre: "Confidentialité") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Aucune donnée collectée")
                        .font(.system(.title3, design: .rounded, weight: .bold))

                    Text("Vos roues, vos options et votre historique de tirages restent sur votre iPhone. Ils ne sont envoyés nulle part et ne sont accessibles à personne d'autre que vous.")

                    Text("Pas de compte, pas de traceur")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("L'app ne demande aucune inscription, n'utilise aucun outil de mesure d'audience et n'intègre aucune régie publicitaire tierce.")

                    Text("Les liens vers nos autres apps")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("La section « Nos autres apps » est une liste embarquée dans l'application. Ouvrir un de ces liens vous emmène sur l'App Store, où les règles d'Apple s'appliquent.")

                    Text("Suppression")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("Supprimer l'application efface toutes les données qu'elle contient. L'historique de chaque roue peut aussi être effacé à tout moment.")

                    Link(destination: Studio.urlConfidentialite) {
                        Label("Version en ligne", systemImage: "arrow.up.forward")
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
