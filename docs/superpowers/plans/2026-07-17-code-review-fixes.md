# Corrections issues de la revue de code du 2026-07-17

Liste des points à traiter un par un. Cocher au fur et à mesure.

## Bugs réels

- [x] **1. `ZeroDivisionError` latent dans `SpritesToIconsService.cut()`**
  `src/cut-mbcmechachu-sprites/module/Service/SpritesToIconsService.py:31`
  `count % round(total / 10)` vaut `count % 0` dès que `total < 5` (`round()` arrondit à 0).
  Aucune `Area` actuelle ne descend sous 10 sprites, mais toute zone plus petite plantera.
  → Corriger avec un garde-fou, ex. `max(1, round(total / 10))`.

- [x] **2. Rectangle mal dimensionné dans `CleanIconService.clean()`**
  `src/cut-mbcmechachu-sprites/module/Service/CleanIconService.py:28-33`
  `draw.rectangle(left, top, width, height)` — la signature Wand attend `(left, top, right, bottom, width, height, ...)`.
  Les 3ᵉ/4ᵉ arguments positionnels sont donc pris pour `right`/`bottom`, pas `width`/`height`.
  Ne « marche » que parce que `dot_left=0` et `dot_top=0` dans `config.ini` et `config.test.ini`.
  → Passer `width=` et `height=` explicitement en keyword args.

- [x] **3. `make placeholders` ne produit aucun changement visible**
  `src/placeholders/make_them_all.sh:28` écrit dans `src/placeholders/tmp/...` (gitignored), jamais dans `images/...`.
  Le step `Fill in missing shiny placeholders` de `.github/workflows/update-images.yml:37-38` est donc un no-op silencieux.
  Déjà noté comme limitation connue dans `docs/superpowers/specs/2026-07-16-image-validation-review-design.md`.
  → Décider : faire copier vers `images/` par le script, ou retirer/renommer le step CI pour ne pas induire en erreur.

## Petits bugs / hygiène

- [x] **4. Variable `$dimension` fantôme (log cassé)**
  - `src/copy_images/copy_images.sh:13`
  - `src/convert_png_webp/convert_png_webp.sh:11`
  - `src/download-from-pokemon-db/convert.sh:9`
  `printf "Start %s on %s\n" "$file" "$dimension"` référence une variable jamais définie.
  → Retirer `$dimension` ou le remplacer par une info pertinente (dimensions attendues).

- [x] **5. Mauvais texte d'aide pour la cible `check_size` du Makefile**
  `Makefile:57-58` — `## Make places holders for missing images` est copié-collé de la cible `placeholders`.
  → Remplacer par une description correcte (vérification des dimensions des images).

- [x] **6. Glob fragile `*.{png,webp}` dans `copy_images.sh`**
  `src/copy_images/copy_images.sh:18` — si `sourceDir` ne contient qu'une seule extension, la moitié non matchée
  de l'expansion d'accolades reste littérale et est traitée comme fichier manquant.
  Masqué aujourd'hui car `convert.sh` génère toujours les paires png+webp.
  → Activer `shopt -s nullglob` en tête de script, ou boucler séparément sur chaque extension.

- [x] **7. Fichier de log committé par erreur**
  `src/cut-mbcmechachu-sprites/output.txt` (1100 lignes) — sortie `pytest` figée dans le repo depuis `3f0870a9`.
  → Supprimer le fichier et l'ajouter à `.gitignore`.

- [x] **8. `mkdir -p` manquant côté acceptation dans `copy_images.sh`**
  `src/copy_images/copy_images.sh` — la branche de rejet fait `mkdir -p "$(dirname "$targetFile")"` avant de
  router vers `review/...`, mais la branche d'acceptation (`targetFile="$destinationFile"`, vers `images/...`)
  ne crée jamais son dossier de destination. Ne pose pas de souci aujourd'hui car `images/<size>/<file>/` est
  toujours déjà trackée en git, mais silencieusement fragile : un nouveau `<file>` (nouvelle catégorie/dossier
  jamais vu) ferait échouer le `cp` sans que le script s'arrête ni signale d'erreur claire.
  Découvert en écrivant `test_copy_images.sh` pour le point 6 (fixtures sandboxées sans dossier pré-existant).
  → Ajouter `mkdir -p "$(dirname "$destinationFile")"` (ou factoriser avec la branche de rejet).
