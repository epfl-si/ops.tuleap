# Note that this is inteded for development only. 
# Passwords are hardcoded here and must not to be used in production!
# include /keybase/team/epfl_blogwiki/blog_prod.env

TRAEFIK_DIR ?= $(dir $(CURDIR))traefik
DEV_DOMAIN ?= dev.jkldsa.com
MYSQL_ROOT_PASSWORD ?= ROOT

# ------------------------------------------------------------ docker-compose
.PHONY: traefik up down logs ps shell reload nuke

traefik: $(TRAEFIK_DIR)
	cd $(TRAEFIK_DIR) && make up

up: .env traefik
	docker-compose up -d

down:
	docker-compose down

reload:
	docker-compose stop app
	make up

logs:
	docker-compose logs -f

ps:
	docker-compose ps

shell: up
	docker-compose exec app bash

nuke: down
	rm -rf data/mysql data/tuleap
	docker-compose up -d db
	sleep 20
	docker-compose run --rm --entrypoint /usr/bin/tuleap-cfg app setup:mysql --host db --user tuleap --password tuleap --dbname tuleap giallo12 tuleap.dev.jkldsa.com
	docker-compose up -d app
	docker-compose logs -f			

appshell: down
	docker-compose run --rm --entrypoint /bin/bash

.env: .env.example
	cp $< $@
	@echo "Example .env file copied. Please edit according to your needs."
