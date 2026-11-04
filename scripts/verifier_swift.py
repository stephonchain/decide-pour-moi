#!/usr/bin/env python3
"""Contrôle structurel des fichiers Swift, faute de compilateur ici.

Il ne remplace pas `swiftc` : il attrape ce qui se voit sans types —
délimiteurs déséquilibrés, chaînes non refermées, interpolations bancales.
C'est exactement la classe d'erreurs qu'une édition par script introduit.

    python3 scripts/verifier_swift.py [chemin…]
"""

from __future__ import annotations

import sys
from pathlib import Path

PAIRES = {")": "(", "]": "[", "}": "{"}
OUVRANTS = set(PAIRES.values())


def analyser(texte: str) -> list[str]:
    """Rend la liste des anomalies trouvées, vide si le fichier est sain."""
    anomalies: list[str] = []
    pile: list[tuple[str, int]] = []          # délimiteur, ligne
    ligne = 1
    i, n = 0, len(texte)
    # Profondeur d'interpolation : chaque `\(` ouvert dans une chaîne.
    chaines: list[int] = []                   # pile des `(` d'interpolation

    while i < n:
        c = texte[i]

        if c == "\n":
            ligne += 1
            i += 1
            continue

        # Commentaires
        if texte.startswith("//", i):
            i = texte.find("\n", i)
            if i == -1:
                break
            continue
        if texte.startswith("/*", i):
            profondeur, i = 1, i + 2
            while i < n and profondeur:
                if texte.startswith("/*", i):
                    profondeur, i = profondeur + 1, i + 2
                elif texte.startswith("*/", i):
                    profondeur, i = profondeur - 1, i + 2
                else:
                    if texte[i] == "\n":
                        ligne += 1
                    i += 1
            if profondeur:
                anomalies.append(f"commentaire /* non refermé")
            continue

        # Chaînes multilignes
        if texte.startswith('"""', i):
            depart = ligne
            i += 3
            while i < n and not texte.startswith('"""', i):
                if texte[i] == "\n":
                    ligne += 1
                i += 1
            if i >= n:
                anomalies.append(f"ligne {depart} : chaîne \"\"\" non refermée")
                break
            i += 3
            continue

        # Chaînes simples, interpolation comprise
        if c == '"':
            depart = ligne
            i += 1
            ferme = False
            while i < n:
                if texte[i] == "\\":
                    if texte.startswith("\\(", i):
                        chaines.append(ligne)
                        niveau, i = 1, i + 2
                        while i < n and niveau:
                            if texte[i] == "(":
                                niveau += 1
                            elif texte[i] == ")":
                                niveau -= 1
                            elif texte[i] == "\n":
                                ligne += 1
                            elif texte[i] == '"':
                                # Chaîne imbriquée dans l'interpolation.
                                i += 1
                                while i < n and texte[i] != '"':
                                    i += 2 if texte[i] == "\\" else 1
                            i += 1
                        chaines.pop()
                        continue
                    i += 2
                    continue
                if texte[i] == '"':
                    ferme = True
                    i += 1
                    break
                if texte[i] == "\n":
                    break
                i += 1
            if not ferme:
                anomalies.append(f"ligne {depart} : chaîne \" non refermée")
            continue

        if c in OUVRANTS:
            pile.append((c, ligne))
        elif c in PAIRES:
            if not pile:
                anomalies.append(f"ligne {ligne} : « {c} » sans ouvrant")
            elif pile[-1][0] != PAIRES[c]:
                ouvrant, ligne_ouvrante = pile[-1]
                anomalies.append(
                    f"ligne {ligne} : « {c} » ferme un « {ouvrant} » (ligne {ligne_ouvrante})"
                )
                pile.pop()
            else:
                pile.pop()
        i += 1

    for ouvrant, ligne_ouvrante in pile:
        anomalies.append(f"ligne {ligne_ouvrante} : « {ouvrant} » jamais refermé")
    return anomalies


def main() -> int:
    racines = [Path(a) for a in sys.argv[1:]] or [Path("DecidePourMoi"),
                                                  Path("DecidePourMoiTests"),
                                                  Path("DecidePourMoiUITests")]
    fichiers = sorted(
        f for racine in racines
        for f in ([racine] if racine.is_file() else racine.rglob("*.swift"))
    )
    total = 0
    for fichier in fichiers:
        anomalies = analyser(fichier.read_text(encoding="utf-8"))
        for anomalie in anomalies:
            print(f"{fichier}:{anomalie}")
        total += len(anomalies)

    print(f"--- {len(fichiers)} fichiers, {total or 'aucune'} anomalie"
          f"{'s' if total > 1 else ''}")
    return 1 if total else 0


if __name__ == "__main__":
    raise SystemExit(main())
