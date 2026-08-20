# Décide pour moi

Application iOS d'aide à la décision : une roue personnalisable pour trancher
n'importe quoi en un geste. Qui fait la vaisselle, quel resto ce soir, quel
élève passe au tableau.

Gratuite, sans compte, sans publicité tierce, sans serveur. Tout reste sur
l'iPhone.

## Ouvrir le projet

```bash
open DecidePourMoi.xcodeproj
```

- iOS 17 minimum, iPhone, portrait
- SwiftUI, SwiftData, CoreHaptics, StoreKit — aucune dépendance externe
- Xcode 16 minimum (groupes synchronisés, String Catalog, Swift Testing)
- Localisée en français et en anglais

Avant la première compilation, choisissez votre équipe de signature dans
*Signing & Capabilities* : le projet est livré sans `DEVELOPMENT_TEAM`.

## Lancer les tests

```bash
xcodebuild test -scheme DecidePourMoi -destination 'platform=iOS Simulator,name=iPhone 16'
```

Les tests portent sur `SpinEngine`, le moteur de tirage : uniformité sur
10 000 tirages, respect des pondérations, cohérence entre part angulaire et
probabilité, atterrissage sur le bon segment, modes sans remise et ordre de
passage, timeline des tics haptiques.

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

## À renseigner avant publication

`DecidePourMoi/Services/Studio.swift` regroupe l'adresse de contact et l'URL
publique de la politique de confidentialité.

## Spécifications

Le document de référence complet est dans [`docs/specifications.md`](docs/specifications.md).
