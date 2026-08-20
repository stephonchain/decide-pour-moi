import Foundation
import SwiftUI

struct ReglagesView: View {

    @AppStorage(CleReglage.son) private var son = Reglages.sonParDefaut
    @AppStorage(CleReglage.confettis) private var confettis = Reglages.confettisParDefaut
    @AppStorage(CleReglage.paletteParDefaut) private var paletteParDefaut = 0
    @AppStorage(CleReglage.langue) private var langue = Langue.systeme.rawValue
    @State private var confidentialiteAffichee = false

    var body: some View {
        FeuilleSombre(titre: tr("Réglages")) {
            List {
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
                    Text(tr("Décide pour moi fonctionne entièrement hors ligne. Aucune donnée n'est collectée, aucun compte n'est nécessaire."))
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
        FeuilleSombre(titre: tr("Confidentialité")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(tr("Aucune donnée collectée"))
                        .font(.system(.title3, design: .rounded, weight: .bold))

                    Text(tr("Vos roues, vos options et votre historique de tirages restent sur votre iPhone. Ils ne sont envoyés nulle part et ne sont accessibles à personne d'autre que vous."))

                    Text(tr("Pas de compte, pas de traceur"))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(tr("L'app ne demande aucune inscription, n'utilise aucun outil de mesure d'audience et n'intègre aucune régie publicitaire tierce."))

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
