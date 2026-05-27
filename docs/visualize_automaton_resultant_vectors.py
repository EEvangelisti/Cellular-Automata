#!/usr/bin/env python3
# visualize_automaton_resultant_vectors.py
#
# Visualise la finesse angulaire produite par le regroupement de plusieurs
# cycles d'un automate à voisinage de Moore.
#
# Principe :
#   - un cycle donne 8 directions élémentaires ;
#   - k cycles donnent 8^k séquences possibles ;
#   - on somme les k pas élémentaires ;
#   - on représente les directions résultantes sous forme de rosaces.
#
# Exemples :
#   python visualize_automaton_resultant_vectors.py --max-cycles 6 --normalize-diagonals
#   python visualize_automaton_resultant_vectors.py --max-cycles 6 --mode vectors
#   python visualize_automaton_resultant_vectors.py --max-cycles 6 --mode directions --color-by-count

import argparse
import math
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt


def moore_vectors(normalize_diagonals=False):
    """Retourne les 8 vecteurs du voisinage de Moore."""
    vecs = np.array(
        [
            (1, 0), (1, 1), (0, 1), (-1, 1),
            (-1, 0), (-1, -1), (0, -1), (1, -1),
        ],
        dtype=float,
    )

    if normalize_diagonals:
        norms = np.linalg.norm(vecs, axis=1)
        vecs = vecs / norms[:, None]

    return vecs


def resultant_vector_counts(n_cycles, vectors, decimals=12):
    """
    Calcule les vecteurs résultants possibles après n_cycles.

    Programmation dynamique : on ne déroule pas explicitement les 8^k
    trajectoires, mais on conserve les positions finales distinctes et leur
    multiplicité.
    """
    counts = Counter({(0.0, 0.0): 1})

    for _ in range(n_cycles):
        new_counts = Counter()
        for (x, y), count in counts.items():
            for dx, dy in vectors:
                key = (round(x + dx, decimals), round(y + dy, decimals))
                new_counts[key] += count
        counts = new_counts

    return counts


def collapse_to_directions(vector_counts, angle_decimals=12):
    """
    Convertit les vecteurs résultants en directions unitaires.

    Les vecteurs colinéaires sont fusionnés. Leur multiplicité est additionnée.
    Le vecteur nul, possible pour certains nombres de cycles, est conservé
    séparément car il n'a pas de direction.
    """
    direction_counts = defaultdict(int)
    zero_count = 0

    for (x, y), count in vector_counts.items():
        r = math.hypot(x, y)

        if r < 1e-12:
            zero_count += count
            continue

        theta = round(math.atan2(y, x), angle_decimals)
        direction_counts[theta] += count

    return dict(direction_counts), zero_count


def draw_quiver(ax, x, y, counts, color_by_count=False, width=0.004):
    """Dessine une rosace de flèches depuis l'origine."""
    n = len(x)

    if n == 0:
        ax.scatter([0], [0], s=30)
        return None

    if color_by_count:
        c = np.log10(np.asarray(counts, dtype=float))
        return ax.quiver(
            np.zeros(n), np.zeros(n), x, y, c,
            angles="xy",
            scale_units="xy",
            scale=1,
            width=width,
            alpha=0.9,
            pivot="tail",
        )

    return ax.quiver(
        np.zeros(n), np.zeros(n), x, y,
        angles="xy",
        scale_units="xy",
        scale=1,
        width=width,
        alpha=0.72,
        pivot="tail",
    )


def plot_panel(ax, n_cycles, vectors, mode="directions", color_by_count=False,
               decimals=12, angle_decimals=12):
    """Dessine un panneau pour un nombre donné de cycles."""
    vector_counts = resultant_vector_counts(n_cycles, vectors, decimals=decimals)
    n_sequences = 8 ** n_cycles
    n_vectors = len(vector_counts)

    if mode == "directions":
        direction_counts, zero_count = collapse_to_directions(
            vector_counts,
            angle_decimals=angle_decimals,
        )

        angles = np.array(sorted(direction_counts.keys()), dtype=float)
        x = np.cos(angles)
        y = np.sin(angles)
        counts = np.array([direction_counts[a] for a in sorted(direction_counts.keys())])

        mappable = draw_quiver(
            ax, x, y, counts,
            color_by_count=color_by_count,
            width=0.004,
        )

        ax.scatter([0], [0], s=20, zorder=3)

        lim = 1.15
        ax.set_xlim(-lim, lim)
        ax.set_ylim(-lim, lim)

        title = (
            f"{n_cycles} cycle{'s' if n_cycles > 1 else ''} : "
            f"{len(direction_counts):,} directions"
        ).replace(",", " ")

        if zero_count:
            title += f"\n+ {zero_count:,} zero-net-displacement seq.".replace(",", " ")

        ax.set_xlabel("cos θ")
        ax.set_ylabel("sin θ")

    elif mode == "vectors":
        coords = np.array(list(vector_counts.keys()), dtype=float)
        counts = np.array(list(vector_counts.values()), dtype=float)
        x = coords[:, 0]
        y = coords[:, 1]

        # Le vecteur nul est représenté par un point au centre, pas par une flèche.
        keep = np.hypot(x, y) > 1e-12
        zero_count = int(np.sum(counts[~keep]))
        x = x[keep]
        y = y[keep]
        counts = counts[keep]

        mappable = draw_quiver(
            ax, x, y, counts,
            color_by_count=color_by_count,
            width=0.0028,
        )

        ax.scatter([0], [0], s=20, zorder=3)

        max_r = max(1.0, float(np.max(np.hypot(x, y))) if len(x) else 1.0)
        lim = max_r * 1.12
        ax.set_xlim(-lim, lim)
        ax.set_ylim(-lim, lim)

        title = (
            f"{n_cycles} cycle{'s' if n_cycles > 1 else ''} : "
            f"{n_vectors:,} vectors"
        ).replace(",", " ")

        if zero_count:
            title += f"\n+ {zero_count:,} zero-net-displacement seq.".replace(",", " ")

        ax.set_xlabel("Δx")
        ax.set_ylabel("Δy")

    else:
        raise ValueError("mode doit valoir 'directions' ou 'vectors'.")

    ax.set_title(title)
    ax.set_aspect("equal")
    ax.axhline(0, lw=0.7, alpha=0.35)
    ax.axvline(0, lw=0.7, alpha=0.35)

    return mappable, n_sequences, n_vectors


def make_figure(max_cycles=6, normalize_diagonals=False, mode="directions",
                color_by_count=False, out="automaton_resultant_vectors.png",
                dpi=220, decimals=12, angle_decimals=12):
    vectors = moore_vectors(normalize_diagonals=normalize_diagonals)

    ncols = min(3, max_cycles)
    nrows = math.ceil(max_cycles / ncols)

    fig, axes = plt.subplots(
        nrows, ncols,
        figsize=(4.5 * ncols, 4.5 * nrows),
        squeeze=False,
        constrained_layout=True,
    )
    axes = axes.ravel()

    last_mappable = None
    for i in range(max_cycles):
        mappable, _, _ = plot_panel(
            axes[i],
            i + 1,
            vectors,
            mode=mode,
            color_by_count=color_by_count,
            decimals=decimals,
            angle_decimals=angle_decimals,
        )
        if mappable is not None:
            last_mappable = mappable

    for ax in axes[max_cycles:]:
        ax.axis("off")

    diag = "normalized diagonal steps" if normalize_diagonals else "unscaled Moore neighbourhood"
    subject = "Resultant directions" if mode == "directions" else "Resultant vectors"

    fig.suptitle(
        f"{subject} after grouping multiple cycles ({diag})",
        fontsize=15,
    )

    if color_by_count and last_mappable is not None:
        cbar = fig.colorbar(last_mappable, ax=axes[:max_cycles], shrink=0.72)
        cbar.set_label("log10(sequence multiplicity)")

    out = Path(out)
    fig.savefig(out, dpi=dpi)
    print(f"Figure écrite : {out.resolve()}")


def main():
    parser = argparse.ArgumentParser(
        description="Rosaces de directions ou de vecteurs résultants pour un automate à 8 voisins."
    )
    parser.add_argument("--max-cycles", type=int, default=6,
                        help="Nombre maximal de cycles à représenter.")
    parser.add_argument("--out", default="automaton_resultant_vectors.png",
                        help="Nom du fichier de sortie.")
    parser.add_argument("--dpi", type=int, default=220)
    parser.add_argument("--normalize-diagonals", action="store_true",
                        help="Normalise les pas diagonaux pour que les 8 directions élémentaires aient la même longueur.")
    parser.add_argument("--mode", choices=["directions", "vectors"], default="directions",
                        help="'directions' = flèches unitaires par angle ; 'vectors' = vrais vecteurs de déplacement final.")
    parser.add_argument("--color-by-count", action="store_true",
                        help="Colore les flèches selon la multiplicité des séquences qui produisent la direction/le vecteur.")
    parser.add_argument("--decimals", type=int, default=12,
                        help="Arrondi des coordonnées pour fusionner les vecteurs identiques.")
    parser.add_argument("--angle-decimals", type=int, default=12,
                        help="Arrondi des angles pour fusionner les directions colinéaires.")
    args = parser.parse_args()

    if args.max_cycles < 1:
        raise ValueError("--max-cycles doit être >= 1")

    make_figure(
        max_cycles=args.max_cycles,
        normalize_diagonals=args.normalize_diagonals,
        mode=args.mode,
        color_by_count=args.color_by_count,
        out=args.out,
        dpi=args.dpi,
        decimals=args.decimals,
        angle_decimals=args.angle_decimals,
    )


if __name__ == "__main__":
    main()
