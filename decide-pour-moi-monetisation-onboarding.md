# Décide pour moi. Monétisation, onboarding et paywall. Instructions Claude Code

Document d'instructions pour transformer l'app gratuite existante en freemium payant.
Stack : SwiftUI existant + RevenueCat (SDK purchases-ios). RevenueCat est déjà dans ta stack, il gère les reçus, les essais et te donne le dashboard de conversion sans rien coder côté serveur.

---

## 1. Le modèle (récapitulatif de la décision)

- **Gratuit** : une roue.
- **Premium** ("toute l'app") : trois offres
  - Hebdomadaire : 1,99 EUR
  - Mensuel : 3,99 EUR avec **3 jours d'essai gratuit**
  - Achat unique (lifetime) : 9,99 EUR
- Onboarding de 15 pages (démos + questions) qui débouche sur le paywall.

## 2. Configuration App Store Connect + RevenueCat

### 2.1 Produits App Store Connect
| Produit | Type | ID suggéré | Prix | Offre d'intro |
|---|---|---|---|---|
| Hebdo | Abonnement auto-renouvelable | `dpm_premium_weekly` | 1,99 EUR | aucune |
| Mensuel | Abonnement auto-renouvelable | `dpm_premium_monthly` | 3,99 EUR | 3 jours gratuits |
| Lifetime | Achat non consommable | `dpm_premium_lifetime` | 9,99 EUR | n/a |

- Les deux abonnements dans le même groupe d'abonnements ("Premium"), le mensuel en rang supérieur.
- L'essai de 3 jours se configure dans App Store Connect comme offre d'introduction du mensuel, pas dans le code.

### 2.2 RevenueCat
- Un entitlement unique : `premium`. Les trois produits l'accordent.
- Un offering `default` avec les trois packages (weekly, monthly, lifetime).
- Tout le gating dans l'app teste UNIQUEMENT `customerInfo.entitlements["premium"]?.isActive == true`. Jamais les IDs produits en dur.

## 3. Matrice gratuit / premium (proposition, à trancher avant de coder)

"Une roue gratuite" à préciser pour Claude Code. Ma recommandation :

| Capacité | Gratuit | Premium |
|---|---|---|
| Nombre de roues | 1 seule (modifiable à volonté) | Illimité |
| Tirage avec remise | Oui | Oui |
| Sans remise + Ordre de passage | Non | Oui |
| Pondération des options | Non | Oui |
| Palettes | 2 | 6 |
| Historique des tirages | Non | Oui |
| Roues préinstallées | Visibles mais verrouillées (teaser) | Débloquées |

Logique : le gratuit prouve la magie du produit (une vraie roue qui tourne bien), le premium débloque tout ce qui crée l'usage répété. Chaque ligne verrouillée est un point de contact paywall.

## 4. Onboarding 15 pages

### 4.1 Principes de construction
- Format quiz interactif (le pattern qui convertit le mieux) : l'utilisateur INVESTIT des réponses avant de voir le prix, ce qui crée l'engagement et personnalise le paywall.
- Chaque page : une seule idée, un seul tap pour avancer, barre de progression fine en haut. Rythme cible : 4 à 8 secondes par page.
- Les réponses aux questions sont stockées localement et réutilisées sur le paywall ("Pour vos repas en famille...").
- Bouton retour discret, pas de bouton "Passer" avant la page 13 (assumé, c'est le but du funnel).
- Haptiques sur chaque sélection, transitions rapides (0,25 s).

### 4.2 Séquence page par page

| # | Type | Contenu |
|---|---|---|
| 1 | Accueil | Logo animé + "Décide pour moi". Sous-titre : "Arrêtez d'hésiter. Laissez la roue trancher." CTA "Commencer" |
| 2 | Démo interactive | Une roue "Ce soir on mange..." tourne toute seule puis invite : "Essayez, lancez-la." L'utilisateur fait un vrai tirage, confettis. C'est le moment magique, le plus tôt possible |
| 3 | Question | "Vous arrive-t-il d'hésiter longtemps pour des petites décisions ?" Tout le temps / Souvent / Parfois |
| 4 | Validation + fait | Réponse reprise : "Vous n'êtes pas seul. On prend 35 000 décisions par jour, et la fatigue décisionnelle est réelle." |
| 5 | Question multi | "Où hésitez-vous le plus ?" Repas / Films et sorties / Qui fait quoi à la maison / En classe ou au travail / Entre amis (choix multiples) |
| 6 | Démo ciblée | Roue pré-remplie selon la réponse dominante de la page 5 (ex. roue "corvées" si maison). Deuxième tirage réel |
| 7 | Question | "Combien de temps perdez-vous par jour à hésiter ?" Moins de 10 min / 10 à 30 min / Plus de 30 min |
| 8 | Projection | "Soit environ X heures par mois. Décide pour moi tranche en 5 secondes." (X calculé depuis la réponse) |
| 9 | Fonction | Mode "Ordre de passage" montré en 3 secondes d'animation (liste qui se remplit). "Parfait pour les profs et les tournois" |
| 10 | Fonction | Pondération montrée visuellement (un segment qui grossit). "Donnez plus de chances à vos envies" |
| 11 | Question | "Qui décidera avec vous ?" Ma famille / Mes amis / Mes élèves ou collègues / Juste moi |
| 12 | Preuve sociale | 3 courts avis (vrais dès que possible, sinon bénéfices reformulés) + note. Pas de faux chiffres |
| 13 | Engagement | "Prêt à ne plus jamais bloquer sur une décision ?" CTA "Je suis prêt". Apparition du "Passer" discret |
| 14 | Récap personnalisé | "Votre plan : des roues pour [réponses page 5], le mode ordre de passage, tirages illimités." Coche animée par ligne |
| 15 | **Paywall** | Voir section 5 |

### 4.3 Détails d'implémentation
- Module `Onboarding/` : `OnboardingFlow` (TabView paginé désactivé au swipe, avancement programmatique), `OnboardingState` (réponses, page courante), une vue par page.
- L'onboarding ne s'affiche qu'au premier lancement (`hasCompletedOnboarding` en UserDefaults), MAIS reste accessible depuis les réglages ("Revoir la présentation").
- Les utilisateurs existants de la version gratuite ne revoient PAS l'onboarding : ils reçoivent le paywall contextuel (section 6) avec un message "Décide pour moi évolue". Leurs roues existantes restent toutes utilisables (acquis, jamais reprendre ce qui a été donné) mais la création de nouvelles roues passe sous la limite gratuite. Point crucial pour les avis.

## 5. Paywall (page 15 et réutilisable partout)

### 5.1 Structure de l'écran
1. Titre bénéfice : "Débloquez tout Décide pour moi"
2. 4 lignes de bénéfices avec coches (roues illimitées, tous les modes, pondération, historique)
3. **Les 3 offres en cartes verticales** :
   - Mensuel PRÉSÉLECTIONNÉ, badge "3 JOURS GRATUITS", libellé "3,99 EUR/mois après l'essai"
   - Lifetime avec badge "MEILLEURE OFFRE", libellé "9,99 EUR une fois, à vie" (l'ancre de valeur : moins de 3 mois d'abonnement)
   - Hebdo en dernier, sobre : "1,99 EUR/semaine" (son rôle est de rendre les deux autres évidentes)
4. CTA plein largeur dont le texte suit la sélection : "Commencer mes 3 jours gratuits" / "Débloquer à vie" / "Continuer"
5. Sous le CTA, en petit mais lisible : mention de renouvellement automatique et d'annulation à tout moment dans les réglages App Store (obligatoire pour la review)
6. Ligne de liens : Restaurer mes achats | Conditions (EULA) | Confidentialité (tous trois OBLIGATOIRES)
7. Croix de fermeture en haut : présente mais discrète, apparition après 2 secondes. Ne jamais faire un paywall infermable, c'est un motif de rejet et d'avis assassins.

### 5.2 Comportements
- Achat et restore via RevenueCat (`Purchases.shared.purchase(package:)`), états de chargement et erreurs gérés proprement (réseau coupé = message clair, pas de spinner infini).
- Succès : animation de célébration, puis retour au contexte d'origine avec la fonction débloquée.
- Fermeture du paywall d'onboarding : l'utilisateur atterrit sur sa roue gratuite, pleinement fonctionnelle. La première expérience hors paywall doit rester excellente : c'est elle qui ramène au paywall plus tard.

## 6. Déclencheurs du paywall dans l'app (après l'onboarding)

- Tentative de créer une 2e roue
- Tap sur un mode verrouillé (sans remise, ordre de passage), une palette verrouillée, l'historique, une roue préinstallée verrouillée
- Badge cadenas discret sur tout élément premium (jamais de fonction cachée : tout est visible, verrouillé)
- Bouton "Premium" permanent et sobre dans les réglages
- Pas de popup spontané à l'ouverture en V1. On mesure d'abord ce funnel propre.

## 7. Conformité et points de vigilance

- **Review Apple** : prix affichés clairement, conditions d'essai explicites ("puis 3,99 EUR/mois"), restore présent, liens EULA et confidentialité fonctionnels, paywall fermable. Le motif de rejet le plus courant est un paywall qui masque le prix réel de l'après-essai.
- **App Privacy à mettre à jour** : avec RevenueCat, déclarer "Historique des achats" (données non liées à l'identité si tu restes en mode anonyme RevenueCat, sans appUserID custom). L'app n'est plus "Aucune donnée collectée" : la fiche doit être corrigée, sinon rejet.
- **Cohérence du studio** : les encarts promo dans tes autres apps qui référencent cette app doivent être mis à jour (nouveau nom "Décide pour moi", et elle n'est plus "gratuite" dans l'accroche).
- **Prix hebdo** : 1,99 EUR/semaine est agressif (103 EUR/an). Assumé dans ce modèle où il sert d'ancre, mais surveille les avis : si l'hebdo génère du ressentiment sans conversions, retire-le, le funnel tiendra sur mensuel + lifetime.

## 8. Ordre de développement dans Claude Code

1. **RevenueCat** : SDK, clé API, offering `default`, entitlement `premium`, `PremiumManager` (Observable) exposant `isPremium` à toute l'app + restore. Testable en sandbox avant toute UI.
2. **Gating** : appliquer la matrice section 3. Un seul modificateur réutilisable `.premiumGated(feature:)` qui affiche le cadenas et route vers le paywall.
3. **Paywall** : écran section 5, réutilisable (init avec un contexte d'origine pour adapter le titre), branché sur tous les déclencheurs section 6.
4. **Onboarding** : les 15 pages section 4, avec les deux démos interactives réelles (réutiliser le composant roue existant).
5. **Migration des utilisateurs existants** : détection d'une installation antérieure (présence de roues + absence du flag onboarding), grand-père sur leurs roues existantes, message d'évolution.
6. **Fiche App Store** : nouveau nom, nouvelles captures (dont une du paywall, c'est autorisé et ça préqualifie), App Privacy corrigée, textes des achats intégrés.
7. **Tests** : sandbox complet (essai, achat, expiration, restore, lifetime), toutes les erreurs réseau, et le parcours gratuit de bout en bout sans jamais toucher le paywall.

## 9. Mesure (dashboard RevenueCat, aucun SDK en plus)

- Taux de complétion d'onboarding (pages vues via un simple log local si besoin)
- Taux de départ d'essai depuis le paywall d'onboarding (cible saine : 5 à 10 % des installs)
- Conversion essai → payant (cible : 30 à 50 %)
- Répartition mensuel / lifetime / hebdo
- Décision à J+30 : si le lifetime domine largement, monter son prix (12,99 EUR) ; si l'hebdo ne convertit personne, le retirer.
