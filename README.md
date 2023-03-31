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
bash src/download-from-pokemon-db/download-from-pokemondb.sh src/download-from-pokemon-db/pokemons-list.txt rs 2> src/download-from-pokemon-db/errors.log
```

And see report_*.txt and errors.log files

#### Cut MBCMechachu sprites

##### Requirement

```
sudo apt-get update && sudo apt-get install imagemagick
```

Sources: https://www.deviantart.com/mbcmechachu/art/National-Pokedex-Icon-Dex-824897934 and https://www.deviantart.com/mbcmechachu/art/National-Pokedex-Icon-Dex-Shiny-910547529

```
bash src/cut-mbcmechachu-sprites/cut-mbcmechachu-sprites.sh complete r 2> src/cut-mbcmechachu-sprites/errors_regulars.log
bash src/cut-mbcmechachu-sprites/cut-mbcmechachu-sprites.sh complete s 2> src/cut-mbcmechachu-sprites/errors_shinies.log
```

And see report_*.txt and errors.log files

#### Placeholders sprites

##### Requirement

```
sudo apt-get update && sudo apt-get install imagemagick
```

```
bash src/placeholders/make_them_all.sh s
bash src/placeholders/make_them_all.sh b
```

### Transfert des données

```
gcloud storage cp ./images/banner/* gs://pokenini-pokemons-icons/banner/

gcloud storage cp ./images/big/regular/* gs://pokenini-pokemons-icons/big/regular
gcloud storage cp ./images/big/shiny/* gs://pokenini-pokemons-icons/big/shiny

gcloud storage cp ./images/small/regular/* gs://pokenini-pokemons-icons/small/regular
gcloud storage cp ./images/small/shiny/* gs://pokenini-pokemons-icons/small/shiny
```

