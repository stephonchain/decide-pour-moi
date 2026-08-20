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
| Premium mensuel | Abonnement auto-renouvelable | `dpm_premium_monthly` | 3,99 € | 1 |
| Premium hebdo | Abonnement auto-renouvelable | `dpm_premium_weekly` | 1,99 € | 2 |
| Premium à vie | Achat non consommable | `dpm_premium_lifetime` | 9,99 € | — |

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
`offering.weekly` et `offering.lifetime`, qui ne fonctionnent qu'avec les
types standards de RevenueCat :

| Package | Identifiant à choisir | Produit rattaché |
|---|---|---|
| Monthly | `$rc_monthly` | `dpm_premium_monthly` |
| Weekly | `$rc_weekly` | `dpm_premium_weekly` |
| Lifetime | `$rc_lifetime` | `dpm_premium_lifetime` |

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

## L'échelle de prix

Le modèle est celui du document de monétisation : mensuel 3,99 € avec trois
jours d'essai, hebdomadaire 1,99 €, à vie 9,99 €.

L'offre à vie tient son rôle d'ancre de valeur parce qu'elle coûte moins de
trois mois d'abonnement. L'hebdomadaire, lui, n'est pas là pour convertir :
à 1,99 € la semaine il revient à 103 € l'an, ce qui rend les deux autres
formules évidentes. C'est un choix assumé, à surveiller dans les avis — si
l'hebdomadaire génère du ressentiment sans conversions, il se retire sans
toucher au reste du funnel.

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


---

## « Aucune offre disponible » : les trois causes

Le paywall n'invente rien : il affiche ce que la source lui donne. Quand il
ne donne rien, c'est l'une de ces trois raisons.

**Les produits App Store Connect ne sont pas complets.** Un produit en
« Métadonnées manquantes » — capture d'écran de revue absente, description
vide — n'est servi ni au sandbox, ni à RevenueCat. Il faut le faire passer
en « Prêt à envoyer ». La capture demandée est une image de l'écran où
l'achat est proposé : le paywall lui-même fait l'affaire.

**L'offering RevenueCat n'est pas configuré.** Le SDK ne lit pas App Store
Connect directement : il sert ce qui est déclaré dans son propre tableau de
bord. Il faut y créer les trois produits, un offering marqué *current*, et y
attacher les packages.

**La propagation prend du temps.** Un produit tout juste complété met de
quelques minutes à quelques heures à devenir visible.

## Se débloquer sans attendre

Le fichier `DecidePourMoi.storekit` ne dépend ni d'Apple ni de RevenueCat :
il contient les trois produits en dur. Pour l'utiliser alors qu'une clé
RevenueCat est configurée, forcez la source dans **Réglages → Debug →
Source des achats → StoreKit local**, puis relancez l'app — le SDK ne se
configure qu'une fois au lancement.

La ligne « Source active » juste en dessous indique laquelle est réellement
en service, ce qui évite de chercher longtemps.


---

## La capture d'écran de revue : 640 × 920

Le champ « Capture d'écran de revue » d'un achat intégré n'a rien à voir avec
les captures marketing de la fiche App Store. Il n'accepte pas les tailles
d'écran iPhone : une capture prise sur l'appareil ou dans le simulateur est
refusée telle quelle.

La taille qui passe est **640 × 920 pixels**, en `.png`, `.jpg` ou `.jpeg`.

Cette capture n'est vue que par l'équipe de revue d'Apple, jamais par un
utilisateur. Elle doit simplement montrer l'écran où l'achat est proposé,
prix et mentions compris — le paywall convient parfaitement, et la même
image sert pour les trois produits.

### Convertir une capture iPhone

Le rapport de forme d'un iPhone n'est pas celui du 640 × 920 : redimensionner
de force déformerait l'image. On la met donc à l'échelle puis on complète sur
les côtés avec le fond de l'app, ce qui garde l'écran entier, mentions
légales comprises.

```bash
# 1. Mise à l'échelle : le plus grand côté passe à 920 px
sips -Z 920 capture.png --out /tmp/etape1.png

# 2. Complément latéral jusqu'à 640 × 920, dans l'indigo de l'app
sips -p 920 640 --padColor 1E1E3C /tmp/etape1.png --out /tmp/etape2.png

# 3. Passage en JPEG : supprime toute couche alpha, souvent en cause
sips -s format jpeg -s formatOptions 90 /tmp/etape2.png --out paywall-revue.jpg

# 4. Contrôle
sips -g pixelWidth -g pixelHeight paywall-revue.jpg
```

`sips` est livré avec macOS, rien à installer. La dernière commande doit
afficher exactement 640 et 920.


---

## Le fichier StoreKit n'est actif que lancé par Xcode

C'est le piège du test local : la configuration StoreKit est un réglage du
schéma, injecté par Xcode au lancement. Une app relancée depuis l'écran
d'accueil tourne **sans** — `Product.products` revient vide et le paywall
affiche « Aucune offre disponible », alors même que « Source active » dit
StoreKit.

La séquence correcte, après avoir changé la source dans Réglages → Debug :
arrêter l'app depuis Xcode, puis ⌘R. Jamais de relance à la main depuis
l'écran d'accueil pendant les tests StoreKit.

## Le paywall distant exige d'être dessiné

`RevenueCatUI.PaywallView` sans paywall conçu dans le tableau de bord
affiche un gabarit de secours (« No Paywall configured », prix en dollars,
lien vers le dashboard). L'app détecte désormais ce cas et retombe sur le
paywall maison : le gabarit de secours ne peut plus atteindre un
utilisateur. Pour utiliser le paywall distant, dessinez-le dans
RevenueCat → Paywalls et attachez-le à l'offering `default`.

## Aligner le tableau de bord RevenueCat sur le modèle

Le paywall de test montrait Monthly / Yearly / Lifetime : l'offering du
tableau de bord contient un package annuel, alors que le modèle retenu est
hebdo / mensuel / à vie. À corriger dans RevenueCat → Offerings :

1. supprimer le package Yearly (`$rc_annual`) de l'offering `default` ;
2. ajouter le package Weekly (`$rc_weekly`) ;
3. attacher à chaque package le produit `dpm_premium_*` correspondant.

Les prix en dollars viennent du Test Store (clé `test_…`) : ce sont ses
produits fictifs, pas ceux d'App Store Connect. Ils disparaîtront avec le
passage à la clé `appl_…`.
