# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Source of the Pokémon images and banners of pokénin.fr, plus the shell scripts that download, convert, check and generate them. There is no application: no `package.json`, no build. The public mirror served to the site is `pokenini-resources` (see `make copy` there).

## Commands

```sh
make help            # list every target
make install         # create the local Apache container serving images/
make check_size      # verify image dimensions
make img_convert     # PNG -> WebP
make banner_generate # composite banners per $BANNER_CONFIG_FILE
bash src/banner_generate/test_generate.sh   # tests of the banner generator (needs imagemagick, jq)
```

## Layout

- `src/<tool>/` — one folder per task, each a Bash script (some with a test script next to it).
- `images/` — the images (`dex/`, `pokemon/`), the output of the scripts.
- `review/` — images waiting for a manual review.
- `docs/` — dated specs and plans, one per piece of work (`YYYY-MM-DD-subject.md`).

## Commits and releases

Conventional Commits (`type(scope): subject`), rules in `.commitlintrc.json`, checked by the `Conventional commits` workflow and, locally, by the hook enabled with `make hooks`. On every push on `main`, `release.yml` runs semantic-release.

## Écarts au guide

Ce dépôt est un dépôt de scripts shell et d'images, pas un projet Node ni PHP. Les règles suivantes du guide de bonnes pratiques n'ont pas d'objet ici :

- **DOC-04** : pas de `doc/` ; l'état stable est dans ce fichier et les specs datées dans `docs/` (DOC-05).
- **ARCH-01**, **ARCH-02** : pas de modules JavaScript, donc pas de dependency-cruiser.
- **COV-***, **MUT-***, **CI-13** : pas de code testable par Vitest ni Stryker, pas de dépendances npm à auditer.
- **VER-09** : pas de version applicative embarquée dans un build.
- **UPD-01**, **UPD-04** : pas de dépendances Node ; Dependabot couvre `github-actions`.
