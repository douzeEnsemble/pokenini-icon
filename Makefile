# Misc
.DEFAULT_GOAL = help
.PHONY        : help build start stop

## —— 🎵 🐳 The Symfony-docker Makefile 🐳 🎵 ——————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z0-9\./_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

ma_cible:
	./mon_script.sh arg1 arg2 arg3

## —— Downloads sprites from PokemonDB ⏬ ————————————————————————————————————————————————————————————————
pkmndb_download: ## Download images from Pokemon DB website
	bash src/download-from-pokemon-db/download-from-pokemondb.sh \
		src/download-from-pokemon-db/pokemons-list.txt \
		rs 2> src/download-from-pokemon-db/errors.log
		
pkmndb_convert: ## Convert png to webp
	bash src/download-from-pokemon-db/convert.sh regular
	bash src/download-from-pokemon-db/convert.sh shiny

pkmndb_copy: ## Copy file into final directories
	bash src/download-from-pokemon-db/cp.sh big regular
	bash src/download-from-pokemon-db/cp.sh big shiny

## —— Cut MBCMechachu sprites ✂️ ————————————————————————————————————————————————————————————————
mcbm_prepare: ## Prepare the Docker Image
	docker build ./src/cut-mbcmechachu-sprites --rm \
		-t cut-mbcmechachu-sprites

mcbm_run: ## Run the cut
	docker run -it --rm -v ./src/cut-mbcmechachu-sprites:/usr/src/app \ 
		cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py \
		regular complete
	docker run -it --rm -v ./src/cut-mbcmechachu-sprites:/usr/src/app \ 
		cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py \
		shiny complete

mcbm_copy: ## Copy file into final directories
	bash src/cut-mbcmechachu-sprites/cp.sh small regular
	bash src/cut-mbcmechachu-sprites/cp.sh small shiny

## —— Placeholders sprites 👤 ————————————————————————————————————————————————————————————————
placeholders: ## Make the placeholders
	bash src/placeholders/make_them_all.sh s
	bash src/placeholders/make_them_all.sh b

