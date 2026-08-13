# Banner

Banner are made with https://pixlr.com/fr/e/#editor.

Use `.pxz` file to have layers and data.
Export to `.png` into `public/img/dex/banner`

> This doc now describes the design source only (the `.pxz`/`.xcf` layered
> file and how it's edited). The export/generation step is automated by
> `src/banner_generate/generate.sh` (see the "Banner generator" section in
> the repo's top-level `README.md`) — export each layer as a named PNG,
> reference it from `src/banner_generate/banners.json`, and the script
> composites the final banners instead of manual pixlr/GIMP exports.
