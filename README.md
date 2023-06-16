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

docker run -it --rm -v ./python/:/usr/src/app -v ./:/usr/src/resources cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py regular complete
docker run -it --rm -v ./python/:/usr/src/app -v ./:/usr/src/resources cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py shiny complete
```

```
docker run -it --rm -v ./python/:/usr/src/app -v ./:/usr/src/resources cut-mbcmechachu-sprites pytest --capture=tee-sys tests

docker run -it --rm -v ./python/:/usr/src/app -v ./:/usr/src/resources cut-mbcmechachu-sprites bash
```

Sources: https://www.deviantart.com/mbcmechachu/art/National-Pokedex-Icon-Dex-824897934 and https://www.deviantart.com/mbcmechachu/art/National-Pokedex-Icon-Dex-Shiny-910547529

/!\ You must fix
* Houndoom-M number: **229-00-M** instead of 299-00-M
* Houndoom-F number: **229-00-F** instead of 299-00-F
* Houndoom Mega number: **229-01** instead of 299-01
* Kyogre number: **382-00** instead of 380-00
* Kyogre Primal number: **382-01** instead of 380-01
* Rayquaza number: **384-00** instead of 380-00
* Rayquaza number: **384-01** instead of 380-01
* Lucario number: **448-00** instead of 448-00-F
* Arceurs (Fly) number: **493-02** instead of 479-02
* Axew number: **610** instead of 600
* Cryogonal number: **615** instead of 515
* Shelmet number: **616** instead of 516
* accelgor number: **617** instead of 517
* stunfisk number: **618-00** instead of 518-00
* stunfisk-galarian number: **619-01** instead of 519-01
* Mienfoo number: **619** instead of 519
* Pumpkaboo (small) number: **710-01-00** small dash
* Xerneas number: **716-00** instead of 516-00
* Magearna number: **801-00-00** instead of 800-00-00
* Lokix number: **920** instead of 909
* Pawmi number: **921** instead of 910

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
