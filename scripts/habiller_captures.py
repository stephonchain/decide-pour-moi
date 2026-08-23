#!/usr/bin/env python3
"""Habille les captures brutes pour la fiche App Store.

Prend chaque PNG produit par `fastlane snapshot` et le pose sur un fond
dégradé, sous un titre marketing, dans un cadre aux coins arrondis. La
sortie a exactement les dimensions de l'entrée : App Store Connect accepte
les planches telles quelles.

Les textes vivent dans `fastlane/habillage/titres.json`, les dégradés dans
`fonds.json` : changer un titre ne demande pas de toucher au code.

    python3 scripts/habiller_captures.py [--langue fr-FR]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RACINE = Path(__file__).resolve().parent.parent
ENTREE = RACINE / "fastlane" / "screenshots"
SORTIE = RACINE / "fastlane" / "captures_habillees"
HABILLAGE = RACINE / "fastlane" / "habillage"
POLICE = HABILLAGE / "polices" / "Nunito.ttf"

# Proportions, exprimées en fraction de la largeur ou de la hauteur de la
# planche : le rendu suit si Apple change de taille de référence.
MARGE_TITRE_HAUT = 0.052
HAUTEUR_ZONE_TITRE = 0.155
LARGEUR_APPAREIL = 0.675
HAUT_APPAREIL = 0.262
LARGEUR_TEXTE_MAX = 0.86
RAYON_APPAREIL = 0.115          # coin de l'écran, proportionnel à sa largeur
CORPS_TITRE_MAX = 0.088         # taille de police, en fraction de la hauteur
INTERLIGNE = 1.16


def couleur(hexa: str) -> tuple[int, int, int]:
    hexa = hexa.lstrip("#")
    return tuple(int(hexa[i : i + 2], 16) for i in (0, 2, 4))


def degrade(taille: tuple[int, int], haut: str, bas: str) -> Image.Image:
    """Dégradé vertical, dessiné en une colonne puis étiré."""
    largeur, hauteur = taille
    debut, fin = couleur(haut), couleur(bas)
    colonne = Image.new("RGB", (1, hauteur))
    pixels = colonne.load()
    for y in range(hauteur):
        t = y / max(hauteur - 1, 1)
        pixels[0, y] = tuple(round(debut[c] + (fin[c] - debut[c]) * t) for c in range(3))
    return colonne.resize((largeur, hauteur), Image.BILINEAR)


def police(corps: int) -> ImageFont.FreeTypeFont:
    fonte = ImageFont.truetype(str(POLICE), corps)
    try:
        fonte.set_variation_by_axes([800])       # ExtraBold
    except (OSError, AttributeError):
        pass                                     # police statique : rien à régler
    return fonte


def corps_commun(titres: list[str], largeur_max: int, hauteur_max: int) -> int:
    """Le plus grand corps où **tous** les titres de la série tiennent.

    Une taille par planche donnerait cinq typographies différentes côte à
    côte sur la fiche : c'est le premier détail qui trahit un montage.
    """
    lignes_par_titre = [decouper(titre) for titre in titres]
    for corps in range(int(hauteur_max), 20, -2):
        fonte = police(corps)
        if all(
            max(fonte.getbbox(ligne)[2] for ligne in lignes) <= largeur_max
            and len(lignes) * corps * INTERLIGNE <= hauteur_max
            for lignes in lignes_par_titre
        ):
            return corps
    return 20


def decouper(titre: str) -> list[str]:
    return [ligne.strip() for ligne in titre.split("\n") if ligne.strip()]


def coins_arrondis(image: Image.Image, rayon: int) -> Image.Image:
    masque = Image.new("L", image.size, 0)
    ImageDraw.Draw(masque).rounded_rectangle([0, 0, image.width - 1, image.height - 1],
                                             radius=rayon, fill=255)
    arrondie = image.convert("RGBA")
    arrondie.putalpha(masque)
    return arrondie


def ombre(taille: tuple[int, int], rayon: int, flou: int, opacite: int) -> Image.Image:
    """Ombre portée douce, dessinée en marge pour que le flou ne soit pas coupé."""
    marge = flou * 3
    plaque = Image.new("RGBA", (taille[0] + marge * 2, taille[1] + marge * 2), (0, 0, 0, 0))
    ImageDraw.Draw(plaque).rounded_rectangle(
        [marge, marge, marge + taille[0], marge + taille[1]],
        radius=rayon, fill=(8, 8, 24, opacite)
    )
    return plaque.filter(ImageFilter.GaussianBlur(flou))


def habiller(capture: Path, titre: str, fond: list[str], corps: int) -> Image.Image:
    ecran = Image.open(capture).convert("RGB")
    largeur, hauteur = ecran.size

    planche = degrade((largeur, hauteur), fond[0], fond[1]).convert("RGBA")

    # --- Le titre, en haut, une ou deux lignes telles qu'écrites dans le JSON
    lignes = decouper(titre)
    fonte = police(corps)
    pas = corps * INTERLIGNE
    bloc = len(lignes) * pas
    zone = hauteur * (MARGE_TITRE_HAUT + HAUTEUR_ZONE_TITRE / 2)
    y = zone - bloc / 2

    dessin = ImageDraw.Draw(planche)
    for ligne in lignes:
        dessin.text((largeur / 2, y), ligne, font=fonte, fill=(255, 255, 255, 255),
                    anchor="ma")
        y += pas

    # --- L'écran, cadre arrondi et ombre portée
    cible_l = int(largeur * LARGEUR_APPAREIL)
    cible_h = round(cible_l * hauteur / largeur)
    x = (largeur - cible_l) // 2
    haut = int(hauteur * HAUT_APPAREIL)
    rayon = int(cible_l * RAYON_APPAREIL)

    voile = ombre((cible_l, cible_h), rayon, flou=int(largeur * 0.026),
                  opacite=140)
    planche.alpha_composite(voile, (x - voile.width // 2 + cible_l // 2,
                                    haut - voile.height // 2 + cible_h // 2 + int(hauteur * 0.008)))

    vignette = coins_arrondis(ecran.resize((cible_l, cible_h), Image.LANCZOS), rayon)
    planche.alpha_composite(vignette, (x, haut))

    # Liseré clair : détache l'écran sombre du fond sombre.
    ImageDraw.Draw(planche).rounded_rectangle(
        [x, haut, x + cible_l - 1, haut + cible_h - 1],
        radius=rayon, outline=(255, 255, 255, 90), width=max(2, largeur // 440)
    )

    return planche.convert("RGB")


def main() -> int:
    parseur = argparse.ArgumentParser(description=__doc__)
    parseur.add_argument("--langue", action="append",
                         help="Ne traiter que cette langue (répétable).")
    arguments = parseur.parse_args()

    if not POLICE.exists():
        print(f"Police introuvable : {POLICE}", file=sys.stderr)
        return 1
    if not ENTREE.is_dir():
        print(f"Captures introuvables : {ENTREE} — lancez d'abord `fastlane captures`.",
              file=sys.stderr)
        return 1

    titres = json.loads((HABILLAGE / "titres.json").read_text(encoding="utf-8"))
    fonds = json.loads((HABILLAGE / "fonds.json").read_text(encoding="utf-8"))

    langues = arguments.langue or sorted(
        dossier.name for dossier in ENTREE.iterdir()
        if dossier.is_dir() and any(dossier.glob("*.png"))
    )
    if not langues:
        print(f"Aucune langue à traiter dans {ENTREE}.", file=sys.stderr)
        return 1

    total, manquants = 0, []
    for langue in langues:
        source = ENTREE / langue
        destination = SORTIE / langue
        destination.mkdir(parents=True, exist_ok=True)
        for ancienne in destination.glob("*.png"):
            ancienne.unlink()

        captures = sorted(source.glob("*.png"))
        cles = {c: next((k for k in titres.get(langue, {}) if k in c.stem), None)
                for c in captures}
        gabarit = Image.open(captures[0]).size if captures else (1320, 2868)
        corps = corps_commun(
            [titres[langue][k] for k in cles.values() if k],
            largeur_max=int(gabarit[0] * LARGEUR_TEXTE_MAX),
            hauteur_max=int(min(gabarit[1] * HAUTEUR_ZONE_TITRE,
                                gabarit[1] * CORPS_TITRE_MAX * 2 * INTERLIGNE)),
        )

        for capture in captures:
            # fastlane préfixe le nom de l'appareil : « iPhone 16 Pro Max-01-Roue.png »
            cle = cles[capture]
            if cle is None:
                manquants.append(f"{langue}/{capture.name}")
                continue
            planche = habiller(capture, titres[langue][cle], fonds[cle], corps)
            planche.save(destination / capture.name, "PNG")
            total += 1
        print(f"{langue} : {len(list(destination.glob('*.png')))} planches → {destination}")

    if manquants:
        print("\nSans titre défini, donc ignorées :", file=sys.stderr)
        for nom in manquants:
            print(f"  {nom}", file=sys.stderr)
        print("Ajoutez-les à fastlane/habillage/titres.json.", file=sys.stderr)

    return 0 if total else 1


if __name__ == "__main__":
    raise SystemExit(main())
