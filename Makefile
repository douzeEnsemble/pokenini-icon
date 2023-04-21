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
	docker create -it --read-only --name pokenini-icon -p 8082:80 -v "${PWD}/images":/usr/local/apache2/htdocs/ httpd:2.4

start: ## Start the project
	docker start pokenini-icon

stop: ## Stop the project
	docker stop pokenini-icon
