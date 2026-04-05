ENV_FILE ?= .env
DOCKER_COMPOSE := docker compose --env-file $(ENV_FILE)

POSTGRES_FILE := postgres/docker-compose.yml
CLICKHOUSE_FILE := clickhouse/docker-compose.yml
REDIS_FILE := redis/docker-compose.yml
RABBITMQ_FILE := rabbitmq/docker-compose.broker.yml
PROXY_FILE := proxy/docker-compose.proxy.yml
LOGGING_FILE := logging/docker-compose.logging.yml

BASE_STACKS := $(POSTGRES_FILE) $(CLICKHOUSE_FILE) $(REDIS_FILE) $(RABBITMQ_FILE)
OBS_STACKS := $(PROXY_FILE) $(LOGGING_FILE)
ALL_STACKS := $(BASE_STACKS) $(OBS_STACKS)

.PHONY: help init-env up up-base up-obs down down-base down-obs restart restart-base restart-obs ps ps-base ps-obs logs logs-base logs-obs config config-base config-obs pull pull-base pull-obs

help:
	@printf '%s\n' \
		'Usage:' \
		'  make init-env      Copy .env.example to .env if .env is missing' \
		'  make up            Start all infra stacks' \
		'  make up-base       Start postgres, clickhouse, redis, rabbitmq' \
		'  make up-obs        Start proxy and logging' \
		'  make down          Stop all infra stacks' \
		'  make ps            Show running containers for all stacks' \
		'  make logs          Tail logs for all stacks' \
		'  make config        Validate all compose files' \
		'' \
		'Override env file:' \
		'  make up ENV_FILE=.env'

init-env:
	@if [ ! -f "$(ENV_FILE)" ]; then cp .env.example "$(ENV_FILE)"; fi

up: up-base up-obs

up-base:
	@for file in $(BASE_STACKS); do $(DOCKER_COMPOSE) -f $$file up -d; done

up-obs:
	@for file in $(OBS_STACKS); do $(DOCKER_COMPOSE) -f $$file up -d; done

down: down-obs down-base

down-base:
	@for file in $(BASE_STACKS); do $(DOCKER_COMPOSE) -f $$file down; done

down-obs:
	@for file in $(OBS_STACKS); do $(DOCKER_COMPOSE) -f $$file down; done

restart: down up

restart-base: down-base up-base

restart-obs: down-obs up-obs

ps:
	@for file in $(ALL_STACKS); do $(DOCKER_COMPOSE) -f $$file ps; done

ps-base:
	@for file in $(BASE_STACKS); do $(DOCKER_COMPOSE) -f $$file ps; done

ps-obs:
	@for file in $(OBS_STACKS); do $(DOCKER_COMPOSE) -f $$file ps; done

logs:
	@for file in $(ALL_STACKS); do $(DOCKER_COMPOSE) -f $$file logs --tail=100; done

logs-base:
	@for file in $(BASE_STACKS); do $(DOCKER_COMPOSE) -f $$file logs --tail=100; done

logs-obs:
	@for file in $(OBS_STACKS); do $(DOCKER_COMPOSE) -f $$file logs --tail=100; done

config:
	@for file in $(ALL_STACKS); do $(DOCKER_COMPOSE) -f $$file config >/dev/null; printf 'ok  %s\n' "$$file"; done

config-base:
	@for file in $(BASE_STACKS); do $(DOCKER_COMPOSE) -f $$file config >/dev/null; printf 'ok  %s\n' "$$file"; done

config-obs:
	@for file in $(OBS_STACKS); do $(DOCKER_COMPOSE) -f $$file config >/dev/null; printf 'ok  %s\n' "$$file"; done

pull:
	@for file in $(ALL_STACKS); do $(DOCKER_COMPOSE) -f $$file pull; done

pull-base:
	@for file in $(BASE_STACKS); do $(DOCKER_COMPOSE) -f $$file pull; done

pull-obs:
	@for file in $(OBS_STACKS); do $(DOCKER_COMPOSE) -f $$file pull; done
