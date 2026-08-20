# Décide pour moi. Spécifications complètes V1

Document de référence pour le développement dans Claude Code.
L'app s'appelle « Décide pour moi » ; le concept reste celui d'une roue de décision.
Plateforme : iOS 17+, iPhone, portrait. SwiftUI, SwiftData. Aucune dépendance externe.

---

## 1. Vision et positionnement

**Pitch** : une roue personnalisable pour trancher n'importe quoi en un geste. Qui fait la vaisselle, quel resto ce soir, quel élève passe au tableau.

**Cibles** : familles, enseignants (tirage d'élèves), soirées entre amis, créateurs de contenu, indécis chroniques.

**Différenciation** : les apps existantes sont truffées de pubs tierces et de paywalls. Ici : gratuit, sans compte, sans pub tierce, sensations premium (physique de roue réaliste, haptiques, confettis). Encarts internes uniquement, catalogue grand public (Memento Mori, Cœur Cosmique, Marque Points).

**Particularité vs les autres apps du studio** : concept universel, donc **localisation FR + EN dès la V1**. Le volume de strings est minuscule, le marché anglophone est énorme sur cette requête.

## 2. Parcours utilisateur cible

1. Ouverture : la dernière roue utilisée est déjà affichée, prête à tourner.
2. Swipe ou tap : la roue part, décélère naturellement, tic haptique à chaque segment.
3. Résultat en overlay avec confettis : Relancer, Retirer l'option, Fermer.
4. Créer une roue : tap sur "+", coller ou taper une liste (une ligne = un segment), c'est prêt.

## 3. Fonctionnalités

### 3.1 La roue (écran principal)
- Rendu plein écran via `Canvas` SwiftUI : segments en arcs colorés, libellés en clair, pointeur fixe en haut.
- Lancement par swipe (la vélocité du geste influence la durée) ou par tap sur le bouton central.
- Physique : décélération réaliste sur 3 à 5 secondes via une courbe custom (ease-out prononcé), pilotée par `TimelineView` ou `CADisplayLink`.
- **Équité** : l'angle final est tiré via `SystemRandomNumberGenerator` AVANT l'animation ; l'animation ne fait qu'y aboutir. Aucun biais possible, mentionné dans la fiche App Store ("tirage vraiment aléatoire").
- Haptiques : tic léger (CoreHaptics) à chaque franchissement de segment, dont la fréquence suit la décélération. Impact fort au résultat. Son optionnel (réglage, coupé par défaut).
- Libellés : taille adaptative, troncature propre au-delà de 20 caractères, jusqu'à 60 segments supportés (au-delà de 20, libellés masqués sur la roue, visibles au résultat).

### 3.2 Résultat
- Overlay : nom de l'option en très grand, confettis, haptique de célébration.
- Boutons : Relancer, Retirer cette option (active le mode sans remise à la volée), Fermer.
- En mode "Ordre de passage" (voir 3.3), le résultat s'ajoute à une liste ordonnée visible.

### 3.3 Modes de tirage (par roue)
- **Avec remise** (défaut) : l'option reste dans la roue.
- **Sans remise** : l'option tirée est retirée jusqu'à réinitialisation. Compteur "restants" affiché.
- **Ordre de passage** : enchaîne les tirages sans remise jusqu'à épuisement et produit une liste ordonnée (parfait profs et tournois). Partage de la liste en texte.
- Réinitialisation en un tap.

### 3.4 Création et édition de roue
- Champ liste : une ligne = une option. Le collage multi-lignes crée toutes les options d'un coup (cas d'usage prof qui colle sa liste d'élèves).
- Pondération optionnelle par option : x1 (défaut), x2, x3. La pondération multiplie la part angulaire ET la probabilité (implémentées ensemble, jamais l'une sans l'autre).
- Réordonnancement par glisser, duplication de roue, suppression.
- Palette de couleurs de la roue : 6 palettes prédéfinies harmonieuses (pas de sélecteur couleur par option en V1, c'est du bruit).

### 3.5 Roues préinstallées (modifiables et supprimables)
- Oui / Non
- Pile ou Face
- Chiffres 1 à 10
- Qui commence ? (Joueur 1 à 4)
- Ce soir on mange... (6 suggestions à personnaliser)

### 3.6 Sauvegarde et partage
- Roues persistées en SwiftData, dernière roue utilisée rouverte au lancement.
- Partage d'une roue en texte simple (titre + une option par ligne) via share sheet ; import par collage dans une nouvelle roue. Pas de format propriétaire, pas de serveur.
- Historique léger par roue : 50 derniers tirages avec horodatage, effaçable.

### 3.7 Réglages
- Son on/off, confettis on/off, palette par défaut
- Section "Nos autres apps" (promo_apps.json, rotation pondérée, carte fermable 14 jours, catalogue grand public)
- Politique de confidentialité, contact, demande d'avis (`SKStoreReviewController`) après le 5e tirage sur 2 jours distincts
- App Privacy : Aucune donnée collectée

## 4. Écrans

| Écran | Contenu | Navigation |
|---|---|---|
| Roue | Roue plein écran, titre, boutons liste et édition | Racine |
| Mes roues | Grille des roues sauvegardées + préinstallées + bouton "+" | Sheet |
| Édition | Titre, liste des options, pondérations, mode de tirage, palette | Sheet |
| Résultat | Overlay (pas un écran séparé) | ZStack |
| Réglages | Voir 3.7 | Sheet |

Premier lancement : la roue "Ce soir on mange..." est affichée, prête à tourner. La première expérience est un tirage, pas un formulaire.

## 5. Architecture

- **Stack** : SwiftUI (Canvas, TimelineView), CoreHaptics, SwiftData, StoreKit. Localisation via String Catalog (fr, en).
- **Pattern** : MVVM léger. `SpinEngine` en type pur testable : entrées (options pondérées, vélocité du geste), sorties (angle cible, durée, timeline des ticks). Tests unitaires : distribution uniforme sur 10 000 tirages, respect des pondérations, mode sans remise.
- **Modèles SwiftData** :

```swift
@Model final class Roue {
    var id: UUID
    var titre: String
    var options: [OptionRoue]     // ordonné
    var mode: ModeTirage          // enum codable
    var paletteID: Int
    var updatedAt: Date
}

@Model final class OptionRoue {
    var id: UUID
    var label: String
    var poids: Int                // 1, 2 ou 3
    var retiree: Bool             // pour le mode sans remise
}
```

## 6. App Store et ASO

- **Nom** : Décide pour moi (EN : Decide for Me)
- **Sous-titre** : Tirage au sort personnalisable / Custom random picker wheel
- **Mots-clés FR** : roue, décision, hasard, tirage, sort, choix, aléatoire, fortune, gage, pioche
- **Mots-clés EN** : wheel, spinner, random, picker, decide, choice, name, raffle, spin, chooser
- **Catégorie** : Utilitaires (secondaire : Style de vie)
- **Arguments fiche** : sans pub tierce, tirage vraiment aléatoire, mode ordre de passage pour les profs
- **Captures** : roue en rotation, résultat confettis, collage d'une liste d'élèves, mode ordre de passage

## 7. Ordre de développement dans Claude Code

1. `SpinEngine` + tests (uniformité, pondérations, sans remise)
2. Rendu Canvas de la roue + animation de rotation pilotée par le moteur
3. Haptiques et overlay résultat
4. Modèles SwiftData, édition de roue, collage multi-lignes
5. Modes de tirage + ordre de passage
6. Roues préinstallées, partage texte, historique
7. Réglages, palettes, encarts promo, localisation EN
8. Polissage : Dynamic Type, VoiceOver (annonce du résultat), mode sombre, performances à 60 segments
9. Icône, captures, fiche App Store bilingue, TestFlight

Estimation : 5 à 6 sessions de travail.

## 8. Direction visuelle

- **Icône** : roue multicolore à 8 segments, moyeu blanc, pointeur en haut, fond indigo profond festif. 1024x1024 sans transparence.
- **In-app** : fond sombre par défaut (la roue colorée est la star), palettes harmonieuses, typographie système arrondie (`.rounded`) pour le côté ludique, chiffres monospaced dans les historiques.

## 9. Hors périmètre V1

- Widget "tirage rapide" et App Intents / Siri (V1.1, très bon candidat)
- Apple Watch
- Sync iCloud
- Thèmes visuels de roue (textures, images)
- Import de fichiers CSV
