# Activer les achats. Guide pas à pas

Trois environnements existent, dans cet ordre de fidélité croissante. Le code
est déjà prêt pour les trois.

| Environnement | Ce qu'il teste | Ce qu'il exige |
|---|---|---|
| Interrupteur « Simuler premium » | Le gating : ce qui est verrouillé, où mène chaque cadenas | Rien, il est déjà là |
| Fichier StoreKit local | Le paywall, les prix, l'achat, la restauration | Rien d'autre |
| Sandbox App Store | La chaîne complète, reçus compris | Les produits dans App Store Connect |

## RevenueCat n'est pas un prérequis

Les achats ont deux implémentations, choisies automatiquement :

- **StoreKit en direct**, tant que `Studio.cleRevenueCat` ne commence pas par
  `appl_`. Le paywall, les prix, l'achat et la restauration fonctionnent
  entièrement. C'est le mode dans lequel se trouve le dépôt aujourd'hui.
- **RevenueCat**, dès que la clé est renseignée. Il prend alors le relais
  sans rien changer d'autre : gestion des reçus, des essais, et surtout le
  tableau de bord de conversion.

Concrètement : vous pouvez faire toute la configuration Apple, tester le
parcours d'achat de bout en bout, et n'ajouter RevenueCat qu'ensuite. Les
identifiants de produits étant les mêmes, la bascule est un copier-coller de
clé.

Le seul écart entre les deux modes tient à la mesure : sans RevenueCat, pas
de statistiques de conversion, et le suivi des abonnements dans le temps
repose sur StoreKit seul. Pour une V1 qu'on veut piloter au chiffre, c'est
une raison suffisante d'y passer avant le lancement.

---

## Étape 1. App Store Connect : créer les trois produits

Dans **Mon app → Monétisation → Achats intégrés** et **Abonnements**.

D'abord le groupe d'abonnements, nommé `Premium`, puis dedans :

| Produit | Type | ID EXACT | Prix | Rang |
|---|---|---|---|---|
| Premium mensuel | Abonnement auto-renouvelable | `monthly` | 3,99 € | 2 |
| Premium annuel | Abonnement auto-renouvelable | `yearly` | à décider | 1 |
| Premium à vie | Achat non consommable | `lifetime` | à décider | — |

Les identifiants doivent être **exactement** ceux-là : ils sont repris dans
`DecidePourMoi.storekit` et devront correspondre à RevenueCat.

Sur le mensuel, ajouter l'**offre d'introduction** : 3 jours, gratuit,
nouveaux abonnés. C'est ici que l'essai se configure, jamais dans le code.

Chaque produit a besoin d'un nom affiché, d'une description et d'une capture
d'écran de validation avant d'être soumis. Pour tester, l'état « Prêt à
soumettre » suffit — inutile d'attendre une validation Apple.

## Étape 2. RevenueCat : entitlement, produits, offering

Sur app.revenuecat.com, créer un projet, puis y ajouter une app iOS avec le
bundle ID `com.stephonchain.decidepourmoi`.

1. **Products** : importer ou saisir les trois identifiants de l'étape 1.
2. **Entitlements** : en créer **un seul**, identifiant `premium`, et lui
   rattacher les trois produits. C'est lui, et lui seul, que le code teste.
3. **Offerings** : créer un offering `default`, le marquer comme *current*,
   et y ajouter trois packages.

**Attention aux identifiants de packages.** Le code lit `offering.monthly`,
`offering.annual` et `offering.lifetime`, qui ne fonctionnent qu'avec les
types standards de RevenueCat :

| Package | Identifiant à choisir | Produit rattaché |
|---|---|---|
| Monthly | `$rc_monthly` | `monthly` |
| Annual | `$rc_annual` | `yearly` |
| Lifetime | `$rc_lifetime` | `lifetime` |

Avec un identifiant personnalisé, la carte correspondante ne s'affichera pas.
Le paywall masque proprement toute offre absente, donc si une carte manque à
l'écran, c'est ici qu'il faut regarder.

4. **API keys** : copier la clé **publique** iOS, celle qui commence par
   `appl_`. Elle est conçue pour être embarquée dans l'app ; la clé secrète,
   elle, ne doit jamais entrer dans le dépôt.

Coller la clé dans `DecidePourMoi/Services/Studio.swift` :

```swift
static let cleRevenueCat = "appl_VotreCleIci"
```

L'étape 2 peut donc attendre. Passez directement à l'étape 3 pour tester ce
que vous venez de créer.

## Étape 3. Tester en local avec le fichier StoreKit

Le schéma partagé pointe déjà sur `DecidePourMoi.storekit`, à la racine du
dépôt. À vérifier une fois : **Product → Scheme → Edit Scheme → Run →
Options → StoreKit Configuration**. Si le champ est vide, y sélectionner le
fichier.

Ce mode ne demande aucun compte, aucun mot de passe, et les achats sont
instantanés. Il sert à voir le paywall avec de vrais prix, à parcourir
l'achat et la restauration.

Pour manipuler l'état pendant l'exécution : **Debug → StoreKit → Manage
Transactions** permet de rembourser, d'expirer un abonnement ou de vider
l'historique. Dans l'éditeur du fichier `.storekit`, l'onglet *Editor →
Enable Interruptions / Failures* permet de simuler les erreurs réseau — à
faire au moins une fois, le paywall doit afficher un message clair et jamais
un rouet infini.

## Étape 4. Tester en sandbox sur un vrai iPhone

C'est le test qui fait foi, et le seul qui valide la chaîne des reçus.

1. App Store Connect → **Utilisateurs et accès → Testeurs Sandbox** → créer
   un compte avec une adresse e-mail qui n'a jamais servi à un Apple ID.
2. Sur l'iPhone : **Réglages → Développeur → Compte Sandbox** (le menu
   Développeur apparaît une fois l'appareil utilisé pour du développement).
   S'y connecter avec le testeur. Ne jamais le faire depuis Réglages → App
   Store, cela consommerait le compte comme un vrai Apple ID.
3. **Retirer le fichier StoreKit du schéma** — sinon les achats restent
   locaux et ne touchent jamais le sandbox.
4. Compiler sur l'appareil et acheter.

En sandbox, les durées sont accélérées : un abonnement mensuel se renouvelle
toutes les 5 minutes et s'arrête après 6 renouvellements, un essai de 3 jours
dure environ 3 minutes. C'est voulu, cela permet de voir l'expiration.

## Ce qu'il faut avoir vérifié avant de soumettre

- L'essai démarre, et le paywall annonce bien le prix qui suivra.
- L'achat à vie débloque, et la restauration le retrouve sur une réinstallation.
- Un abonnement expiré reverrouille bien les fonctions premium.
- Réseau coupé : message clair, pas de blocage.
- Le parcours gratuit complet, sans jamais toucher au paywall, reste agréable.
- Les liens Conditions et Confidentialité du paywall s'ouvrent réellement.

## Pièges connus

**Le paywall reste sur « Chargement des offres… »** — en mode RevenueCat,
l'offering n'est pas marqué *current* ou la clé appartient à un autre projet.
En mode StoreKit direct, le fichier `.storekit` n'est pas sélectionné dans le
schéma et les produits n'existent pas encore côté Apple.

**Une carte d'offre manque** — l'identifiant du package n'est pas un type
standard (voir étape 2), ou le produit n'est pas encore « Prêt à soumettre »
dans App Store Connect.

**« Cannot connect to iTunes Store » en sandbox** — le compte testeur a été
saisi dans Réglages → App Store au lieu de Réglages → Développeur.

**Les achats sandbox ne remontent pas dans RevenueCat** — normal si le
fichier StoreKit local est encore sélectionné dans le schéma.


---

## L'échelle de prix est incohérente en l'état

Le document de monétisation fixait l'offre à vie à 9,99 €, dans un modèle où
elle n'affrontait qu'un hebdomadaire et un mensuel : « moins de trois mois
d'abonnement » en faisait une ancre de valeur redoutable.

L'arrivée de l'annuel casse ce raisonnement. À 9,99 € l'offre à vie est moins
chère que n'importe quel annuel plausible : personne ne s'abonnera à l'année,
et le revenu récurrent — le seul qui compose dans le temps — disparaît.

Trois sorties possibles :

1. **Monter l'offre à vie** à 39,99 € ou 49,99 €, au-dessus de l'annuel. Elle
   redevient ce qu'elle doit être : le choix de qui refuse l'abonnement, pas
   le choix par défaut.
2. **Retirer l'annuel** et revenir au modèle du document, où l'offre à vie à
   9,99 € joue son rôle d'ancre face au mensuel.
3. **Retirer l'offre à vie** et garder mensuel + annuel, le schéma le plus
   courant, qui maximise le récurrent.

Le fichier `DecidePourMoi.storekit` porte pour l'instant 3,99 € / 29,99 € /
9,99 €, uniquement pour que les trois cartes s'affichent en test. Ces prix
n'ont aucun effet en production : seuls comptent ceux d'App Store Connect.

## Le Test Store de RevenueCat

La clé configurée commence par `test_` : elle vise le Test Store de
RevenueCat, qui simule les achats sans passer par Apple. Pratique pour
vérifier le tableau de bord et le paywall distant, mais deux limites :

- les achats n'ont aucune réalité côté App Store, donc rien ne valide la
  configuration d'App Store Connect ;
- il faudra impérativement basculer sur la clé `appl_…` du projet avant
  toute soumission, sinon aucun achat réel ne fonctionnera.

Le repli StoreKit reste donc utile : c'est lui qui teste la vraie chaîne
Apple, en sandbox, avec les vrais reçus.
