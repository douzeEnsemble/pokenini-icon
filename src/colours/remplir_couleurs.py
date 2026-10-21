#!/usr/bin/env python3
"""Remplit les colonnes de couleurs du CSV Pokénini à partir des images.

Pour chaque ligne, le script lit les images « Small Regular Url » (normal) et
« Small Shiny Url » (chromatique), extrait les couleurs dominantes (contour du
sprite exclu) et remplit, uniquement quand la cellule est vide :

  Regular colours codes / Shiny coulours codes             codes hexa
  Regular colours names / Shiny coulours names             noms anglais
  Noms Couleurs normal  / Noms Couleurs chromatique        noms français

Chaque cellule contient 5 lots de couleurs séparés par « | » (couleurs d'un lot
séparées par « ; ») : le lot 1 est le VRAI, les lots 2 à 5 sont des leurres
plausibles (palettes d'autres Pokémon, ou palette réelle au décalage de teinte).
Les lots sont alignés entre les colonnes : le lot n des codes, des noms anglais et
des noms français décrit les mêmes couleurs. Résultat déterministe (relançable).

Les colonnes « (manuel) » et les cellules déjà remplies ne sont jamais modifiées
(sauf avec --force, qui réécrit les 6 colonnes mais garde les « - »).
Les images sont mises en cache : on peut relancer le script sans tout retélécharger.

Dépendances : pip install pillow numpy scikit-learn
Exemple     : python3 remplir_couleurs.py pokemons.csv -o pokemons_couleurs.csv
"""
import argparse
import colorsys
import csv
import hashlib
import io
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from multiprocessing import Pool

import numpy as np
from PIL import Image
from sklearn.cluster import KMeans

COL = {
    "codes": ("Regular colours codes", "Shiny coulours codes"),
    "en": ("Regular colours names", "Shiny coulours names"),
    "fr": ("Noms Couleurs normal", "Noms Couleurs chromatique"),
}

# (anglais, français, hexa) — vocabulaire proche de tes noms manuels.
NOMS = [
    ("black", "noir", "#161616"),
    ("dark gray", "gris foncé", "#4a4a4a"),
    ("gray", "gris", "#8a8a8a"),
    ("light gray", "gris clair", "#c2c2c2"),
    ("white", "blanc", "#f4f4f4"),
    ("cream", "crème", "#f3ead0"),
    ("beige", "beige", "#d8c3a0"),
    ("dark brown", "marron foncé", "#3e2616"),
    ("brown", "marron", "#6e4426"),
    ("light brown", "marron clair", "#a9794a"),
    ("dark red", "rouge foncé", "#7a1717"),
    ("red", "rouge", "#d3262b"),
    ("salmon", "saumon", "#f08a78"),
    ("red orange", "rouge orangé", "#e5532a"),
    ("dark orange", "orange foncé", "#bf5a10"),
    ("orange", "orange", "#f58a1f"),
    ("light orange", "orange clair", "#f9b97a"),
    ("peach", "pêche", "#f8cfae"),
    ("yellow orange", "jaune orangé", "#f5ae1d"),
    ("gold", "doré", "#c9a227"),
    ("yellow", "jaune", "#f6d62a"),
    ("light yellow", "jaune clair", "#faee95"),
    ("olive", "olive", "#79782a"),
    ("lime", "vert citron", "#a8d12c"),
    ("dark green", "vert foncé", "#1f5a2c"),
    ("green", "vert", "#34a540"),
    ("light green", "vert clair", "#8ddb7a"),
    ("mint", "menthe", "#a6e6c8"),
    ("teal", "bleu vert", "#1f8a86"),
    ("turquoise", "turquoise", "#2fc7c0"),
    ("dark blue", "bleu foncé", "#1c2f6e"),
    ("blue", "bleu", "#2f63c8"),
    ("sky blue", "bleu ciel", "#5bbcf0"),
    ("light blue", "bleu clair", "#9cc6f2"),
    ("dark purple", "violet foncé", "#44245f"),
    ("purple", "violet", "#7a40b0"),
    ("light purple", "violet clair", "#b79ae0"),
    ("lavender", "lavande", "#d3c4ee"),
    ("plum", "prune", "#7b2f6d"),
    ("magenta", "magenta", "#d1389b"),
    ("pink", "rose", "#f48fb6"),
    ("light pink", "rose clair", "#f9cfe0"),
    ("dark pink", "rose foncé", "#c2447b"),
]


# ---------------------------------------------------------------- couleurs --
def _rgb(h):
    n = int(h.lstrip("#"), 16)
    return np.array([n >> 16 & 255, n >> 8 & 255, n & 255], float)


def _lab(rgb):
    c = np.atleast_2d(rgb) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805],
                  [0.2126, 0.7152, 0.0722],
                  [0.0193, 0.1192, 0.9505]])
    xyz = (c @ m.T) / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]),
                     200 * (f[:, 1] - f[:, 2])], axis=1)


_NOMS_LAB = _lab(np.array([_rgb(h) for _, _, h in NOMS]))


def nom_couleur(hexa):
    """Renvoie (nom anglais, nom français) de la couleur nommée la plus proche."""
    d = np.linalg.norm(_NOMS_LAB - _lab(_rgb(hexa)), axis=1)
    en, fr, _ = NOMS[int(np.argmin(d))]
    return en, fr


# ----------------------------------------------------------------- leurres --
LOT_SEP = " | "


def _arr(palette, k):
    """Palette (hexa) -> tableau Lab (k, 3), complété en répétant la dernière couleur."""
    lab = _lab(np.array([_rgb(x) for x in palette]))
    if len(lab) < k:
        lab = np.vstack([lab, np.repeat(lab[-1:], k - len(lab), axis=0)])
    return lab[:k]


def distance_palettes(pool, t):
    """Distance moyenne (ΔE, insensible à l'ordre) entre t (k,3) et chaque palette de pool (N,k,3)."""
    d = np.linalg.norm(pool[:, :, None, :] - t[None, None, :, :], axis=3)
    return 0.5 * (d.min(axis=2).mean(axis=1) + d.min(axis=1).mean(axis=1))


def decaler_teinte(palette, angle):
    out = []
    for x in palette:
        r, g, b = _rgb(x) / 255
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        r, g, b = colorsys.hsv_to_rgb((h + angle / 360) % 1, s, v)
        out.append(f"#{round(r * 255):02x}{round(g * 255):02x}{round(b * 255):02x}")
    return out


def choisir_leurres(vrai, pool_pals, pool_lab, rng, n, k):
    """n palettes fausses mais plausibles, distinctes du vrai lot et entre elles."""
    t = _arr(vrai, k)
    choisis, labs = [], []

    def loin_des_choisis(pl, seuil):
        return all(distance_palettes(pl[None], l)[0] >= seuil for l in labs)

    # 1) la vraie palette avec la teinte décalée (moitié des leurres)
    angles = [60, 90, 120, 150, 180, 210, 240, 270, 300]
    rng.shuffle(angles)
    for ang in angles:
        if len(choisis) >= n // 2:
            break
        p = decaler_teinte(vrai, ang)
        pl = _arr(p, k)
        if distance_palettes(pl[None], t)[0] >= 22 and loin_des_choisis(pl, 15):
            choisis.append(p)
            labs.append(pl)

    # 2) palettes réelles d'autres Pokémon, de plus en plus permissif si besoin
    if len(pool_pals):
        d = distance_palettes(pool_lab, t)
        ordre = list(range(len(pool_pals)))
        rng.shuffle(ordre)
        for lo, hi, ecart in [(22, 55, 15), (15, 90, 12), (10, 1e9, 8)]:
            for i in ordre:
                if len(choisis) >= n:
                    break
                if lo <= d[i] <= hi and pool_pals[i] not in choisis and loin_des_choisis(pool_lab[i], ecart):
                    choisis.append(pool_pals[i])
                    labs.append(pool_lab[i])
            if len(choisis) >= n:
                break

    # 3) dernier recours (Pokémon gris sans assez d'autres palettes) : couleurs nommées au hasard
    while len(choisis) < n:
        p = [rng.choice(NOMS)[2] for _ in range(len(vrai))]
        choisis.append(p)
        labs.append(_arr(p, k))
    return choisis[:n]


def graine(*parties):
    return int(hashlib.sha256("|".join(map(str, parties)).encode()).hexdigest()[:16], 16)


def couleurs_dominantes(chemin, k):
    """k couleurs dominantes (hexa), de la plus présente à la moins présente."""
    im = Image.open(chemin).convert("RGBA")
    if max(im.size) > 192:
        im.thumbnail((192, 192), Image.NEAREST)
    a = np.array(im)
    masque = a[:, :, 3] > 128
    # On retire le contour : pixels du sprite qui touchent le vide.
    p = np.pad(masque, 1, constant_values=False)
    interieur = masque & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
    if interieur.sum() < 20:
        interieur = masque
    px = a[:, :, :3][interieur].astype(float)
    if len(px) == 0:
        return []
    k = min(k, len(np.unique(px, axis=0)))
    km = KMeans(n_clusters=k, n_init=5, random_state=0).fit(px)
    ordre = np.argsort(-np.bincount(km.labels_, minlength=k))
    res = []
    for i in ordre:
        r, g, b = (int(round(x)) for x in km.cluster_centers_[i])
        res.append(f"#{r:02x}{g:02x}{b:02x}")
    return res


def _worker(args):
    chemin, k = args
    try:
        return chemin, couleurs_dominantes(chemin, k)
    except Exception as e:  # image illisible
        return chemin, f"ERREUR: {e}"


# ------------------------------------------------------------ téléchargement --
def chemin_cache(cache, url):
    return os.path.join(cache, urllib.parse.urlparse(url).path.lstrip("/"))


def telecharger(args):
    url, dest = args
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return url, None
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    p = urllib.parse.urlparse(url)
    sûre = urllib.parse.urlunparse(p._replace(path=urllib.parse.quote(p.path, safe="/%")))
    req = urllib.request.Request(sûre, headers={"User-Agent": "Mozilla/5.0 (couleurs-pokenini)"})
    derniere = None
    for essai in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read()
            tmp = dest + ".part"
            with open(tmp, "wb") as f:
                f.write(data)
            os.replace(tmp, dest)
            return url, None
        except urllib.error.HTTPError as e:
            derniere = f"HTTP {e.code}"
            if e.code in (403, 404, 410):
                break
        except Exception as e:
            derniere = str(e)
        time.sleep(1.5 * (essai + 1))
    return url, derniere


# -------------------------------------------------------------------- main --
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv_in")
    ap.add_argument("-o", "--sortie", help="CSV de sortie (défaut : <entrée>_couleurs.csv)")
    ap.add_argument("--taille", choices=["small", "big"], default="small", help="images utilisées (défaut : small)")
    ap.add_argument("--couleurs", type=int, default=5, help="nombre de couleurs par image (défaut : 5)")
    ap.add_argument("--sep", default=";", help="séparateur entre valeurs dans une cellule (défaut : ;)")
    ap.add_argument("--cache", default="pokenini_images", help="dossier de cache des images")
    ap.add_argument("--workers", type=int, default=8, help="téléchargements en parallèle")
    ap.add_argument("--offline", action="store_true", help="ne rien télécharger, n'utiliser que le cache")
    ap.add_argument("--limit", type=int, help="ne traiter que les N premières lignes à remplir (essai)")
    ap.add_argument("--leurres", type=int, default=4, help="nombre de lots leurres par cellule (défaut : 4)")
    ap.add_argument("--force", action="store_true", help="réécrire aussi les cellules déjà remplies (sauf « - »)")
    a = ap.parse_args()

    brut = open(a.csv_in, "rb").read()
    bom = brut.startswith(b"\xef\xbb\xbf")
    txt = brut.decode("utf-8-sig")
    fin_de_ligne = "\r\n" if "\r\n" in txt else "\n"
    finit_par_nl = txt.endswith("\n")
    rows = list(csv.reader(io.StringIO(txt, newline="")))
    h = rows[0]
    idx = {c: i for i, c in enumerate(h)}
    taille = a.taille.capitalize()
    url_cols = (f"{taille} Regular Url", f"{taille} Shiny Url")
    manquantes = [c for c in [*url_cols, *(x for p in COL.values() for x in p)] if c not in idx]
    if manquantes:
        sys.exit(f"Colonnes introuvables dans le CSV : {manquantes}")

    def vide(r, col):
        """Cellule à remplir : vide, ou (avec --force) non vide mais différente de « - »."""
        v = r[idx[col]].strip()
        return v == "" or (a.force and v != "-")

    # 1. Quelles images faut-il ?
    besoins = []  # (n° ligne, variante 0/1, url)
    for n, r in enumerate(rows[1:], start=1):
        for v in (0, 1):
            url = r[idx[url_cols[v]]].strip()
            if url and any(vide(r, COL[t][v]) for t in COL):
                besoins.append((n, v, url))
    if a.limit:
        lignes = sorted({n for n, _, _ in besoins})[: a.limit]
        besoins = [b for b in besoins if b[0] in lignes]
    urls = sorted({u for _, _, u in besoins})
    print(f"{len(besoins)} cellules-groupes à remplir, {len(urls)} images distinctes")

    # 2. Téléchargement (avec cache)
    echecs = {}
    if not a.offline:
        todo = [(u, chemin_cache(a.cache, u)) for u in urls]
        with ThreadPoolExecutor(a.workers) as ex:
            for i, (u, err) in enumerate(ex.map(telecharger, todo), 1):
                if err:
                    echecs[u] = err
                if i % 200 == 0 or i == len(todo):
                    print(f"  téléchargées : {i}/{len(todo)} (échecs : {len(echecs)})", flush=True)
    else:
        for u in urls:
            if not os.path.exists(chemin_cache(a.cache, u)):
                echecs[u] = "absente du cache"

    # 3. Extraction des couleurs
    dispo = [u for u in urls if u not in echecs]
    print(f"Extraction des couleurs de {len(dispo)} images…", flush=True)
    palettes = {}
    with Pool() as pool:
        for chemin, res in pool.imap_unordered(
                _worker, [(chemin_cache(a.cache, u), a.couleurs) for u in dispo], chunksize=8):
            palettes[chemin] = res

    # 4. Lots : 1 vrai + leurres, par image distincte et par variante
    vraies = {}  # (url, variante) -> palette
    for n, v, url in besoins:
        pal = palettes.get(chemin_cache(a.cache, url))
        if isinstance(pal, str):
            echecs[url] = pal
        elif pal:
            vraies[(url, v)] = pal
    pools = {}
    for v in (0, 1):
        cles = sorted(c for c in vraies if c[1] == v)
        pals = [vraies[c] for c in cles]
        labs = np.array([_arr(p, a.couleurs) for p in pals]) if pals else np.empty((0, a.couleurs, 3))
        pools[v] = (pals, labs)
    lots = {}
    for (url, v), pal in vraies.items():
        rng = random.Random(graine(url, v))
        leurres = choisir_leurres(pal, *pools[v], rng, a.leurres, a.couleurs)
        lots[(url, v)] = [pal] + leurres

    # 5. Remplissage
    remplies = 0
    for n, v, url in besoins:
        ens = lots.get((url, v))
        if not ens:
            continue
        noms = [[nom_couleur(x) for x in lot] for lot in ens]
        valeurs = {
            "codes": LOT_SEP.join(a.sep.join(lot) for lot in ens),
            "en": LOT_SEP.join(a.sep.join(c[0] for c in lot) for lot in noms),
            "fr": LOT_SEP.join(a.sep.join(c[1] for c in lot) for lot in noms),
        }
        r = rows[n]
        for t, val in valeurs.items():
            if vide(r, COL[t][v]):
                r[idx[COL[t][v]]] = val
        remplies += 1

    # 6. Écriture (mêmes fins de ligne / BOM que l'original)
    sortie = a.sortie or os.path.splitext(a.csv_in)[0] + "_couleurs.csv"
    buf = io.StringIO(newline="")
    csv.writer(buf, lineterminator=fin_de_ligne).writerows(rows)
    out = buf.getvalue()
    if not finit_par_nl and out.endswith(fin_de_ligne):
        out = out[: -len(fin_de_ligne)]
    with open(sortie, "wb") as f:
        f.write((b"\xef\xbb\xbf" if bom else b"") + out.encode("utf-8"))
    print(f"\n{remplies} groupes remplis -> {sortie}")
    if echecs:
        print(f"{len(echecs)} images sans résultat (cellules laissées vides) :")
        for u, e in list(echecs.items())[:15]:
            print(f"  {e:20s} {u}")
        if len(echecs) > 15:
            print(f"  … et {len(echecs) - 15} autres")


if __name__ == "__main__":
    main()
