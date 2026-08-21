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
simulateur iPhone 16 Pro Max une fois par langue, déroule les six écrans
(roue, résultat avec confettis, collage d'une liste d'élèves, grille des
roues, ordre de passage, paywall) et range les PNG dans
`fastlane/screenshots/fr-FR` et `en-US`, barre d'état forcée à 9:41.

Le paywall est capturé hors premium, offres chargées depuis
`DecidePourMoi.storekit` : les prix sont en euros dans les deux langues.
Un rapport HTML s'ouvre à la fin pour tout relire d'un coup d'œil.

Seul le 6,9" est capturé : App Store Connect dérive les tailles plus
petites automatiquement.

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

## Deux pièges connus

- **Localisation anglaise** : les dossiers supposent « English (U.S.) ».
  Si la fiche a été créée en « English (U.K.) », renommer
  `fastlane/metadata/en-US` en `en-GB` et la ligne `languages` du Snapfile.
- **Premier passage** : la cible de tests UI n'a jamais compilé — si un
  identifiant d'accessibilité manque ou qu'un écran met plus de temps que
  prévu, le test échoue proprement avec le nom de l'élément introuvable.
  M'envoyer la sortie, c'est réglé en un échange.
