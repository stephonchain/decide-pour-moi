#!/usr/bin/env python3
"""Vérifie que chaque `tr(…)` du code a sa clé dans le catalogue, traduite
dans toutes les langues.

Une chaîne absente du catalogue s'affiche telle quelle : en français dans
l'app anglaise, sans que rien ne le signale. C'est la panne silencieuse la
plus facile à laisser passer.

    python3 scripts/verifier_traductions.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

CATALOGUE = Path("DecidePourMoi/Resources/Localizable.xcstrings")
SOURCES = Path("DecidePourMoi")
LANGUES = {"fr", "en"}

APPEL = re.compile(r'\btr(?:Riche)?\(\s*"((?:[^"\\]|\\.)*)"')
INTERPOLATION = re.compile(r'\\\((?:[^()]|\([^()]*\))*\)')


def variantes(cle: str) -> set[str]:
    """Les formes possibles d'une clé : le catalogue note une interpolation
    `%lld` pour un entier et `%@` pour tout le reste, et le code ne dit pas
    lequel. On accepte l'une ou l'autre."""
    if not INTERPOLATION.search(cle):
        return {cle}
    morceaux = INTERPOLATION.split(cle)
    nombre = len(morceaux) - 1
    formes = set()
    for masque in range(2 ** nombre):
        resultat = morceaux[0]
        for i in range(nombre):
            resultat += ("%lld" if masque >> i & 1 else "%@") + morceaux[i + 1]
        formes.add(resultat)
    return formes


def main() -> int:
    catalogue = json.loads(CATALOGUE.read_text(encoding="utf-8"))["strings"]
    connues = set(catalogue)

    manquantes: dict[str, str] = {}
    for fichier in sorted(SOURCES.rglob("*.swift")):
        texte = fichier.read_text(encoding="utf-8")
        for trouve in APPEL.finditer(texte):
            brute = trouve.group(1).replace('\\"', '"').replace("\\n", "\n")
            if not (variantes(brute) & connues):
                manquantes.setdefault(brute, str(fichier))

    incompletes = {
        cle: sorted(LANGUES - set(valeur.get("localizations", {})))
        for cle, valeur in catalogue.items()
        if LANGUES - set(valeur.get("localizations", {}))
    }

    if manquantes:
        print(f"{len(manquantes)} clé(s) absente(s) du catalogue :")
        for cle, fichier in sorted(manquantes.items()):
            print(f"  {cle!r}  ({fichier})")
    else:
        print("Clés manquantes : aucune")

    if incompletes:
        print(f"\n{len(incompletes)} clé(s) non traduite(s) :")
        for cle, langues in sorted(incompletes.items()):
            print(f"  {cle!r} → il manque {', '.join(langues)}")
    else:
        print(f"Traductions incomplètes : aucune ({len(catalogue)} clés)")

    return 1 if manquantes or incompletes else 0


if __name__ == "__main__":
    raise SystemExit(main())
