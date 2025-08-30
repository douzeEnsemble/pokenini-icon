# Misc
.DEFAULT_GOAL = help
.PHONY        : help build start stop

## —— 🎵 🐳 The Symfony-docker Makefile 🐳 🎵 ——————————————————————————————————
help: ## Outputs this help screen
	@grep -E '(^[a-zA-Z0-9\./_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}{printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

install: ## Install requirements
install: build start

## —— Docker 🐳 ————————————————————————————————————————————————————————————————
build: ## Builds the Docker images
	docker create -it --name pokenini-icon -p 8083:80 \
		-v "${PWD}/images":/usr/local/apache2/htdocs/ httpd:2.4

start: ## Start the project
	docker start pokenini-icon

stop: ## Stop the project
	docker stop pokenini-icon

## —— Pokemon DB ————————————————————————————————————————————————————————————————
.PHONY        : pdb_dl pdb_convert pdb_copy
pdb_dl: ## Download from pokemondb.net
	rm -f src/download-from-pokemon-db/errors.log
	rm -f src/download-from-pokemon-db/reports*
	bash src/download-from-pokemon-db/download-from-pokemondb.sh src/download-from-pokemon-db/pokemons-list.txt rs 2> src/download-from-pokemon-db/errors.log
pdb_convert: ## Convert images into .webp
	bash src/download-from-pokemon-db/convert.sh regular
	bash src/download-from-pokemon-db/convert.sh shiny
pdb_copy: ## Copy images to the images/ folder
	bash src/download-from-pokemon-db/cp.sh big regular
	bash src/download-from-pokemon-db/cp.sh big shiny

## —— MBCMechachu ————————————————————————————————————————————————————————————————
.PHONY        : mbc_prepare mbc_cut mbc_copy
mbc_prepare: ## Prepare the Docker image
	docker build -f src/cut-mbcmechachu-sprites/Dockerfile src/cut-mbcmechachu-sprites --rm -t cut-mbcmechachu-sprites
mbc_cut: ## Cut the sprites into individual images
	docker run -it --rm -v ./src/cut-mbcmechachu-sprites:/usr/src/app cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py regular complete
	docker run -it --rm -v ./src/cut-mbcmechachu-sprites:/usr/src/app cut-mbcmechachu-sprites python cut-mbcmechachu-sprites.py shiny complete
mbc_copy: ## Copy images to the images/ folder
	bash src/cut-mbcmechachu-sprites/cp.sh small regular
	bash src/cut-mbcmechachu-sprites/cp.sh small shiny

## —— Images ————————————————————————————————————————————————————————————————
.PHONY        : img_convert
img_convert: ## Convert all .png images in images/ to .webp
	bash src/convert_png_webp/convert_png_webp.sh

.PHONY        : placeholders
placeholders: ## Make places holders for missing images
	bash src/placeholders/make_them_all.sh b
	bash src/placeholders/make_them_all.sh s