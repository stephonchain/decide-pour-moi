# Décide pour moi

Application iOS d'aide à la décision : une roue personnalisable pour trancher
n'importe quoi en un geste. Qui fait la vaisselle, quel resto ce soir, quel
élève passe au tableau.

Freemium, sans compte, sans publicité tierce, sans serveur. Les roues et
les tirages restent sur l'iPhone ; seuls les achats passent par l'App Store
et RevenueCat.

## Ouvrir le projet

```bash
open DecidePourMoi.xcodeproj
```

- iOS 17 minimum, iPhone, portrait
- SwiftUI, SwiftData, CoreHaptics, StoreKit + RevenueCat (`purchases-ios`,
  résolu automatiquement par SPM à la première ouverture)
- Xcode 16 minimum (groupes synchronisés, String Catalog, Swift Testing)
- Localisée en français et en anglais

Avant la première compilation, choisissez votre équipe de signature dans
*Signing & Capabilities* : le projet est livré sans `DEVELOPMENT_TEAM`.

## Lancer les tests

```bash
xcodebuild test -scheme DecidePourMoi -destination 'platform=iOS Simulator,name=iPhone 16'
```

Les tests portent sur `SpinEngine` (uniformité sur 10 000 tirages, respect
des pondérations, cohérence entre part angulaire et probabilité, atterrissage
sur le bon segment, modes de tirage, timeline des tics haptiques) et sur la
matrice d'accès freemium (`AccesTests`).

## Organisation du code

| Dossier | Rôle |
|---|---|
| `DecidePourMoi/App` | Point d'entrée et conteneur SwiftData |
| `DecidePourMoi/Engine` | `SpinEngine` : type pur, testable, sans dépendance UI |
| `DecidePourMoi/Models` | Modèles SwiftData (`Roue`, `OptionRoue`, `Tirage`), palettes, roues préinstallées |
| `DecidePourMoi/Services` | Haptiques, sons, réglages, catalogue promo, demande d'avis |
| `DecidePourMoi/Views` | Écrans SwiftUI et rendu `Canvas` de la roue |
| `DecidePourMoi/Resources` | Catalogues de chaînes FR/EN, `promo_apps.json`, `Assets.xcassets` |
| `DecidePourMoiTests` | Tests du moteur (Swift Testing) |

## Équité du tirage

Le gagnant est tiré **avant** l'animation, avec `SystemRandomNumberGenerator`.
L'animation ne fait qu'aboutir à un angle déjà décidé : aucun biais n'est
possible, et la pondération d'une option multiplie sa part angulaire **et** sa
probabilité, jamais l'une sans l'autre.

## Langue

L'app se choisit en français ou en anglais depuis ses propres réglages, sans
passer par ceux de l'iPhone : un téléphone en anglais peut très bien afficher
l'app en français.

Le mécanisme tient dans `DecidePourMoi/Services/Langues.swift`. Toutes les
chaînes passent par `tr(_:)`, qui résout la clé dans le bundle de la langue
choisie plutôt que dans celui du système ; `trRiche(_:)` fait la même chose en
conservant le markdown. La racine applique la `Locale` correspondante — seule
la langue est remplacée, la région de l'utilisateur reste la sienne — et se
reconstruit à chaque changement, sans redémarrage.

Ajouter une chaîne, c'est donc écrire `Text(tr("Mon texte"))` et non
`Text("Mon texte")` : ce dernier suivrait la langue du système et ignorerait
le réglage de l'app.

## Encart « nos autres apps »

Le catalogue est un fichier embarqué, `DecidePourMoi/Resources/promo_apps.json` :
aucun appel réseau, aucune régie tierce, aucun traceur. Une carte à rotation
pondérée apparaît dans « Mes roues » et peut être refermée pour 14 jours ; la
liste complète reste consultable dans les réglages. Ajouter une app se fait en
éditant le JSON, sans toucher au code.

## Freemium, onboarding et paywall

Le modèle est décrit dans [`docs/monetisation-onboarding.md`](docs/monetisation-onboarding.md) :
une roue gratuite, tout le reste en premium (hebdo 1,99 €, mensuel 3,99 €
avec 3 jours d'essai, lifetime 9,99 €).

- **`Services/Acces.swift`** : la matrice gratuit / premium / historique, en
  logique pure et testée. C'est là qu'on ajuste ce qui est gratuit.
- **`Services/PremiumManager.swift`** : le pont RevenueCat. Tout le gating
  teste l'entitlement `premium`, jamais un identifiant de produit.
- **`Views/Paywall/`** : le paywall, unique et réutilisable, adapté au
  contexte d'où il s'ouvre. Prix affichés depuis le store, jamais en dur.
- **`Views/Onboarding/`** : les 15 pages, dont deux démos où l'utilisateur
  fait de vrais tirages, et le stockage local des réponses qui personnalisent
  le paywall.
- **Utilisateurs historiques** : une installation antérieure au freemium est
  détectée au lancement ; tout ce qui a été donné reste acquis, seule la
  création de nouvelles roues passe sous la limite gratuite.

En build DEBUG, un interrupteur « Simuler premium » dans les réglages permet
de tester le gating sans compte RevenueCat.

## À renseigner avant publication

- `DecidePourMoi/Services/Studio.swift` : adresse de contact, URL publique de
  la politique de confidentialité, **clé API publique RevenueCat**.
- App Store Connect : les trois produits (`dpm_premium_weekly`,
  `dpm_premium_monthly` avec offre d'introduction de 3 jours,
  `dpm_premium_lifetime`), le groupe d'abonnements « Premium ».
- RevenueCat : entitlement `premium` accordé par les trois produits,
  offering `default` avec les packages weekly / monthly / lifetime.
- La fiche App Privacy n'est plus « Aucune donnée collectée » : déclarer
  l'historique des achats (non lié à l'identité en mode anonyme RevenueCat).
- Mettre à jour les encarts promo des autres apps du studio : nouveau nom
  « Décide pour moi », et l'accroche ne doit plus dire « gratuite ».

## Spécifications

Le document de référence complet est dans [`docs/specifications.md`](docs/specifications.md).
