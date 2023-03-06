# Pokénini icons

## To Begin

### Webserver

#### Run

```
docker run -dit --name pokenini-icon -p 8082:80 -v "$PWD/images":/usr/local/apache2/htdocs/ httpd:2.4
```

#### Start

```
docker start pokenini-icon
```

#### Stop

```
docker stop pokenini-icon
```

### Scripts

#### Downloads sprites from PokemonDB

```
bash src/download-from-pokemon-db/download-from-pokemondb.sh src/download-from-pokemon-db/pokemons-list.txt
```

And see report.*txt files

#### Cut MBCMechachu sprites

##### Requirement

```
sudo apt-get update && sudo apt-get install imagemagick tesseract-ocr libtesseract-dev
```

Sources: https://www.deviantart.com/mbcmechachu/art/National-Pokedex-Icon-Dex-824897934 and https://www.deviantart.com/mbcmechachu/art/National-Pokedex-Icon-Dex-Shiny-910547529

```
bash src/cut-mbcmechachu-sprites/cut-mbcmechachu-sprites.sh 2> src/cut-mbcmechachu-sprites/errors.log
```

And see errors.log files