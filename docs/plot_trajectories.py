import sys
import xml.etree.ElementTree as ET
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
from matplotlib.collections import LineCollection

xml_path = sys.argv[1]    # votre fichier
min_spots = 10
max_tracks = 2000         # mettez None ou un grand nombre si vous voulez tout
dt = 0.2217               # s (dans votre XML)
lw = 0.2                  # épaisseur traits

tree = ET.parse(xml_path)
root = tree.getroot()

tracks = []  # (xy_recentered, nspots, vmean)

for p in root.findall("particle"):
    det = p.findall("detection")
    n = len(det)
    if n < min_spots:
        continue

    det.sort(key=lambda d: int(d.attrib["t"]))
    xy = np.array([(float(d.attrib["x"]), float(d.attrib["y"])) for d in det], dtype=float)

    # vitesse moyenne = longueur de trajectoire / durée
    steps = xy[1:] - xy[:-1]
    path_len = np.sqrt((steps**2).sum(axis=1)).sum()          # px
    duration = (n - 1) * dt                                   # s
    vmean = path_len / duration if duration > 0 else 0.0       # px/s

    xy -= xy[0]  # recentrer
    tracks.append((xy, n, vmean))

# 1) trier pour l’ordre d’affichage :
#    longues d'abord (dessinées en dessous), courtes ensuite (au-dessus)
#    tracks.sort(key=lambda x: x[1], reverse=True)
# ici on trie plutôt par la vitesse moyenne, des plus grandes aux plus petites
tracks.sort(key=lambda x: x[2], reverse=True)

if max_tracks is not None:
    tracks = tracks[:max_tracks]

# Construire segments pour LineCollection (plus efficace + colorbar)
segs = [xy for (xy, n, v) in tracks]
vals = np.array([v for (xy, n, v) in tracks], dtype=float)

# Normalisation couleurs
norm = mpl.colors.Normalize(vmin=np.percentile(vals, 2), vmax=np.percentile(vals, 98))
cmap = plt.get_cmap("viridis")

fig, ax = plt.subplots(figsize=(7.5, 7.5))

# Tracer en deux passes pour que les courtes soient au-dessus :
# - on garde la couleur vitesse, mais l'ordre contrôle la superposition
#   (LineCollection respecte l'ordre des segments)
lc = LineCollection(segs, cmap=cmap, norm=norm, linewidths=lw)
lc.set_array(vals)
ax.add_collection(lc)

ax.axhline(0, linewidth=1)
ax.axvline(0, linewidth=1)
ax.set_aspect("equal", adjustable="box")
ax.set_xlabel("Δx (px)")
ax.set_ylabel("Δy (px)")
ax.set_title(f"Trajectoires centrées colorées par Vmoy (n={len(tracks)})")

cbar = fig.colorbar(lc, ax=ax)
cbar.set_label("Vitesse moyenne (px/s)")

ax.autoscale()
plt.savefig("trajectoires_recentrées_vitesse.png", dpi=300, bbox_inches="tight")
plt.show()
