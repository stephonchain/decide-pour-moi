# Captures automatiques et publication App Store Connect

Le même principe que pour Pocket Nurse, mais versionné dans le dépôt cette
fois : les captures des deux langues se génèrent en une commande, la fiche
et les captures se publient en une autre. Tout se lance depuis le Mac.

## Préparation (une fois)

1. **fastlane** : `brew install fastlane`
2. **Clé API App Store Connect** — celle du MCP ASC convient si vous l'avez
   gardée. Sinon : App Store Connect → Utilisateurs et accès → Intégrations
   → Clés API → générer (rôle **App Manager**), télécharger le `.p8`.
3. Dans le shell (ou `~/.zshrc`) :

```bash
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ASC_KEY_PATH="$HOME/clefs/AuthKey_XXXXXXXXXX.p8"
```

## Générer les captures (FR + EN)

```bash
cd ~/Developer/decide-pour-moi
fastlane captures
```

Ce que ça fait : compile la cible `DecidePourMoiUITests`, lance le
simulateur iPhone 16 Pro Max une fois par langue, déroule cinq écrans et
range les PNG dans `fastlane/screenshots/fr-FR` et `en-US`, barre d'état
forcée à 9:41.

| Fichier | Écran |
| --- | --- |
| `01-Roue` | La roue d'accueil, prête à tourner |
| `02-Resultat` | Le résultat, confettis compris |
| `03-MesRoues` | La grille des roues |
| `04-Liste` | La liste en texte brut : une ligne = une option |
| `05-OrdreDePassage` | L'ordre de passage après trois tirages |

Pas de capture du paywall : une fiche App Store se vend sur ce que l'app
fait, pas sur son tarif.

Un rapport HTML s'ouvre à la fin pour tout relire d'un coup d'œil. Seul le
6,9" est capturé : App Store Connect dérive les tailles plus petites
automatiquement.

### Ce qui rend le parcours reproductible

Trois arguments de lancement, tous sous `#if DEBUG`, donc absents du
binaire publié :

- `-captures.demo YES` — remet à chaque lancement le même jeu de roues,
  dans la langue du moment (`RouesDeDemo`). Les deux localisations montrent
  donc exactement le même contenu, aux mêmes positions.
- `-debug.premium YES` — tout est déverrouillé, aucun cadenas à l'image.
- `-avis.demande YES` et `-onboarding.fait YES` — ni popup d'avis ni
  tunnel d'accueil au milieu d'une capture.

Le parcours ne tape jamais au clavier : il navigue au doigt et s'appuie sur
des identifiants d'accessibilité. C'est ce qui l'immunise contre l'état du
clavier logiciel du simulateur, principale source d'échecs de ce genre de
test.

## Publier la fiche et les captures

```bash
fastlane publier          # métadonnées + captures des deux langues
fastlane publier_textes   # métadonnées seules
```

`deliver` pousse tout ce que contient `fastlane/metadata/` (nom,
sous-titre, mots-clés, promo, description, URLs, notes de revue) et les
captures, dans les deux localisations, sans toucher au binaire — celui-ci
part par Xcode → Product → Archive, comme d'habitude.

**La vérité vit dans le dépôt** : pour changer un texte de la fiche, on
édite `fastlane/metadata/…` (ou `docs/fiche-app-store.md` puis on reporte),
et on relance `fastlane publier_textes`. Plus jamais d'édition à la main
dans App Store Connect.

## Pièges connus

- **Localisation anglaise** : les dossiers supposent « English (U.S.) ».
  Si la fiche a été créée en « English (U.K.) », renommer
  `fastlane/metadata/en-US` en `en-GB` et la ligne `languages` du Snapfile.
- **Assistant fastlane** : si la commande demande *Would you like to set
  fastlane up?*, répondre **n**. C'est le signe que le dépôt n'est pas à
  jour (`git pull`) ou qu'on n'est pas dans le bon dossier.
- **Un écran manquant** : le parcours continue et va au bout des deux
  langues (`stop_after_first_error(false)`), puis liste ce qui a échoué
  avec le nom de l'élément introuvable. Pour extraire la ligne utile du
  log :

  ```bash
  grep -E "XCTAssertTrue|error:|Failed to|not idle|Crash"     ~/Library/Logs/snapshot/DecidePourMoi-DecidePourMoi.log | head -30
  ```

- **`Executed 0 tests`** : le test n'a pas échoué, il est mort en route —
  l'app a planté ou s'est figée. La commande ci-dessus le dit ; la cause
  classique est une animation qui ne s'arrête jamais, car le système ne
  voit alors plus jamais l'app au repos et toute recherche d'élément
  finit par expirer.
