# Pokénini icons

## To Begin

### Webserver

#### Run

```
make install
```

#### Start

```
make start
```

#### Stop

```
make stop
```

### Scripts

#### Downloads sprites from PokemonDB

```
bash src/download-from-pokemon-db/download-from-pokemondb.sh src/download-from-pokemon-db/pokemons-list.txt rs 2> src/download-from-pokemon-db/errors.log
```

And see report_*.txt and errors.log files

To convert png to webp

```
bash src/download-from-pokemon-db/convert.sh regular
bash src/download-from-pokemon-db/convert.sh shiny
```

To copy downloaded images to the final dir

```
bash src/download-from-pokemon-db/cp.sh big regular
bash src/download-from-pokemon-db/cp.sh big shiny
```

#### Cut MBCMechachu sprites

##### Requirement

```
cd src/cut-mbcmechachu-sprites && docker build . --rm -t cut-mbcmechachu-sprites && cd ../..

rm -Rf src/cut-mbcmechachu-sprites/temp/*

docker run -it --rm -v ./src/cut-mbcmechachu-sprites:/usr/src/app cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py regular complete
docker run -it --rm -v ./src/cut-mbcmechachu-sprites:/usr/src/app cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py shiny complete
```

Sources: https://www.deviantart.com/mbcmechachu/art/National-Pokedex-Icon-Dex-824897934 and https://www.deviantart.com/mbcmechachu/art/National-Pokedex-Icon-Dex-Shiny-910547529

**Need fixing**
* Abomasnow-F number: **0460.00-F** instead of 0450.00-F
* Greninja-Mega number: **0658.00.02** instead of 0658.00.01
* Urshifu-Single-Strike number: **0892.00.00** instead of 0892.00.00.01

**Missing**
* None

To copy cut images to the final dir

```
bash src/cut-mbcmechachu-sprites/cp.sh small regular
bash src/cut-mbcmechachu-sprites/cp.sh small shiny
```

**Testing**

```
docker run -it --rm -v ./src/cut-mbcmechachu-sprites/:/usr/./src/app cut-mbcmechachu-sprites pytest --capture=tee-sys tests

docker run -it --rm -v ./src/cut-mbcmechachu-sprites/:/usr/src/app cut-mbcmechachu-sprites bash
```

#### PNG to WEBP

Convert .png to .webp

```
bash src/convert_png_webp.sh
```

#### Placeholders sprites

##### Requirement

```
sudo apt-get update && sudo apt-get install webp imagemagick
```

```
bash src/placeholders/make_them_all.sh s
bash src/placeholders/make_them_all.sh b
```
