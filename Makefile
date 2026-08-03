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
.PHONY        : pdb_dl pdb_copy
pdb_dl: ## Download from pokemondb.net
	rm -f src/download-from-pokemon-db/errors.log
	rm -f src/download-from-pokemon-db/reports*
	bash src/download-from-pokemon-db/download-from-pokemondb.sh src/download-from-pokemon-db/pokemons-list.txt rs 2> src/download-from-pokemon-db/errors.log
pdb_copy: ## Copy images to the images/ folder
	bash src/download-from-pokemon-db/cp.sh regular
	bash src/download-from-pokemon-db/cp.sh shiny

## —— Koenig sprites ————————————————————————————————————————————————————————————
.PHONY        : koenig_update_sha koenig_dl koenig_select koenig_copy
koenig_update_sha: ## Bump SOURCE_SHA to the latest koenigderluegner/pokemon-sprites commit
	bash src/koenig-sprites/update_sha.sh
koenig_dl: ## Download the pinned koenigderluegner/pokemon-sprites tarball
	bash src/koenig-sprites/download.sh
koenig_select: ## Select and stage sprites matching pokenini's slugs
	bash src/koenig-sprites/select.sh
koenig_copy: ## Copy staged images to the images/ folder
	bash src/koenig-sprites/cp.sh regular
	bash src/koenig-sprites/cp.sh shiny

## —— Images ————————————————————————————————————————————————————————————————
.PHONY        : img_convert
img_convert: ## Convert all .png images in images/ to .webp
	bash src/convert_png_webp/convert_png_webp.sh

.PHONY        : placeholders
placeholders: ## Make places holders for missing images
	bash src/placeholders/make_them_all.sh b
	bash src/placeholders/make_them_all.sh s

.PHONY        : check_size
check_size: ## Check that images have the expected dimensions
	bash src/check_size/check_size.sh images/banner 578 325
	bash src/check_size/check_size.sh images/big 256 256
	bash src/check_size/check_size.sh images/small 68 68