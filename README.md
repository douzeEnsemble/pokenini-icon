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

To copy downloaded images to the final dir

```
bash src/download-from-pokemon-db/cp.sh r
bash src/download-from-pokemon-db/cp.sh s
```

#### Cut MBCMechachu sprites

##### Requirement

```
cd src/cut-mbcmechachu-sprites
docker build . --rm -t cut-mbcmechachu-sprites

docker run -it --rm -v ./python/:/usr/src/app -v ./:/usr/src/resources cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py ../resources/regulars.png r sample ../resources/pokemons-regular-list.csv


docker run -it --rm -v ./python/:/usr/src/app -v ./:/usr/src/resources cut-mbcmechachu-sprites pytest --capture=tee-sys -v tests

docker run -it --rm -v ./python/:/usr/src/app -v ./:/usr/src/resources cut-mbcmechachu-sprites bash
```

Sources: https://www.deviantart.com/mbcmechachu/art/National-Pokedex-Icon-Dex-824897934 and https://www.deviantart.com/mbcmechachu/art/National-Pokedex-Icon-Dex-Shiny-910547529

```
python cut-mbcmechachu-sprites.py ../resources/regulars.png r complete ../resources/pokemons-regular-list.csv
python cut-mbcmechachu-sprites.py ../resources/shinies.png s complete ../resources/pokemons-shiny-list.csv
```

And see report_*.txt and errors.log files

To copy cut images to the final dir

```
bash src/cut-mbcmechachu-sprites/cp.sh r
bash src/cut-mbcmechachu-sprites/cp.sh s
```

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

#### GitHub Pages and Pokénini-Resources

```
git clone git@github.com:douzeEnsemble/pokenini-resources.git
cp -R images/* pokenini-resources/
cd pokenini-resources/
git add .
git commit -m "Update images"
git switch -c dev
git push -u origin dev
cd ..
rm -Rf pokenini-resources
```

#### Google Cloud Storage

##### Uniquement les images nouvelles et mises à jour

```
git add -A -n images | sed -E "s/^.*images\/(.*\.png)'$/\1/" | xargs -n1 sh -c 'gcloud storage cp ./images/$0 gs://pokenini-pokemons-icons/$0'
```

##### Toutes les données

```
gcloud storage cp -n ./images/banner/* gs://pokenini-pokemons-icons/banner/

gcloud storage cp -n ./images/big/regular/* gs://pokenini-pokemons-icons/big/regular
gcloud storage cp -n ./images/big/shiny/* gs://pokenini-pokemons-icons/big/shiny

gcloud storage cp -n ./images/small/regular/* gs://pokenini-pokemons-icons/small/regular
gcloud storage cp -n ./images/small/shiny/* gs://pokenini-pokemons-icons/small/shiny
```

gcloud storage cp ./images/small/regular/* gs://pokenini-pokemons-icons/small/regular
