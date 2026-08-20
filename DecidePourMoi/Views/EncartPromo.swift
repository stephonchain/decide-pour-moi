import Foundation
import SwiftUI

/// Encart pour nos propres apps. Aucune régie tierce, aucun traceur, aucun
/// appel réseau : le catalogue est embarqué dans le bundle.
/// La carte se referme pour 14 jours.
struct EncartPromo: View {

    @State private var app: AppPromue? = nil
    @State private var visible = false

    var body: some View {
        Group {
            if visible, let app {
                carte(app)
            }
        }
        .onAppear(perform: preparer)
    }

    private func preparer() {
        guard Reglages.promoVisible else {
            visible = false
            return
        }
        if app == nil {
            app = CataloguePromo.shared.appAMettreEnAvant(evitant: Reglages.promoDerniereApp)
            Reglages.promoDerniereApp = app?.id
        }
        visible = app != nil
    }

    private func carte(_ app: AppPromue) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Une autre app du studio")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
                Button {
                    Reglages.masquerPromo()
                    withAnimation { visible = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 26, height: 26)
                        .contentShape(.rect)
                }
                .accessibilityLabel(Text("Masquer cette suggestion"))
            }

            Link(destination: app.url) {
                HStack(spacing: 14) {
                    Image(systemName: app.symbole)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(app.couleur.gradient, in: .rect(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.nom)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        Text(app.accroche)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.top, 10)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Ouvre la fiche App Store"))
        }
        .padding(14)
        .background(.white.opacity(0.07), in: .rect(cornerRadius: 18))
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}

/// Catalogue complet, dans les réglages : rien n'est masqué à l'utilisateur.
struct SectionsNosApps: View {
    var body: some View {
        let catalogue = CataloguePromo.shared

        Group {
            if !catalogue.grandPublic.isEmpty {
                Section {
                    ForEach(catalogue.grandPublic) { app in
                        LigneApp(app: app)
                            .listRowBackground(Fond.carte)
                    }
                } header: {
                    Text("Nos autres apps")
                }
            }

            if !catalogue.soignants.isEmpty {
                Section {
                    ForEach(catalogue.soignants) { app in
                        LigneApp(app: app)
                            .listRowBackground(Fond.carte)
                    }
                } header: {
                    Text("Pour les soignants")
                } footer: {
                    Text("Aucune publicité tierce dans cette app. Ces liens mènent uniquement à nos propres applications.")
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }
}

struct LigneApp: View {
    let app: AppPromue

    var body: some View {
        Link(destination: app.url) {
            HStack(spacing: 12) {
                Image(systemName: app.symbole)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(app.couleur.gradient, in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.nom)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(app.accroche)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
