ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
DOCKER_COMPOSE ?= docker compose
NETWORK_NAME ?= pingtower_network

INFRA_ENV := $(ROOT_DIR)/infra/.env
API_ENV := $(ROOT_DIR)/api/.env
EMAIL_ENV := $(ROOT_DIR)/email-service/.env
FRONTEND_ENV := $(ROOT_DIR)/frontend/.env
METRICS_ENV := $(ROOT_DIR)/metrics-writer/.env
PING_ENV := $(ROOT_DIR)/ping-service/.env
STATE_ENV := $(ROOT_DIR)/state-elevator/.env
TG_BOT_ENV := $(ROOT_DIR)/tg-bot/.env

POSTGRES_COMPOSE := $(ROOT_DIR)/infra/postgres/docker-compose.yml
REDIS_COMPOSE := $(ROOT_DIR)/infra/redis/docker-compose.yml
CLICKHOUSE_COMPOSE := $(ROOT_DIR)/infra/clickhouse/docker-compose.yml
RABBITMQ_COMPOSE := $(ROOT_DIR)/infra/rabbitmq/docker-compose.broker.yml
API_COMPOSE := $(ROOT_DIR)/api/docker-compose.yml
EMAIL_COMPOSE := $(ROOT_DIR)/email-service/docker-compose.yml
FRONTEND_COMPOSE := $(ROOT_DIR)/frontend/docker-compose.yml
METRICS_COMPOSE := $(ROOT_DIR)/metrics-writer/docker-compose.yml
PING_COMPOSE := $(ROOT_DIR)/ping-service/docker-compose.yml
STATE_COMPOSE := $(ROOT_DIR)/state-elevator/docker-compose.yml
TG_BOT_COMPOSE := $(ROOT_DIR)/tg-bot/docker-compose.yml

.PHONY: help network migrate up down ps logs \
	infra-up infra-down services-up services-down frontend-up frontend-down \
	api-up api-down email-up email-down metrics-up metrics-down ping-up ping-down \
	state-up state-down tg-bot-up tg-bot-down

help:
	@echo "Targets:"
	@echo "  make -C infra up            # bring up infra, run API migrations, then start all services"
	@echo "  make -C infra down          # stop all services and infra"
	@echo "  make -C infra infra-up      # start postgres, redis, clickhouse, rabbitmq"
	@echo "  make -C infra services-up   # start api, workers and frontend"
	@echo "  make -C infra migrate       # run API EF Core migrator once"
	@echo "  make -C infra ps            # show compose status for all stacks"
	@echo "  make -C infra logs          # tail infra logs"

network:
	@docker network inspect $(NETWORK_NAME) >/dev/null 2>&1 || docker network create $(NETWORK_NAME)

infra-up: network
	$(DOCKER_COMPOSE) --env-file $(INFRA_ENV) -f $(POSTGRES_COMPOSE) up -d
	$(DOCKER_COMPOSE) --env-file $(INFRA_ENV) -f $(REDIS_COMPOSE) up -d
	$(DOCKER_COMPOSE) --env-file $(INFRA_ENV) -f $(CLICKHOUSE_COMPOSE) up -d
	$(DOCKER_COMPOSE) --env-file $(INFRA_ENV) -f $(RABBITMQ_COMPOSE) up -d

infra-down:
	-$(DOCKER_COMPOSE) --env-file $(INFRA_ENV) -f $(RABBITMQ_COMPOSE) down
	-$(DOCKER_COMPOSE) --env-file $(INFRA_ENV) -f $(CLICKHOUSE_COMPOSE) down
	-$(DOCKER_COMPOSE) --env-file $(INFRA_ENV) -f $(REDIS_COMPOSE) down
	-$(DOCKER_COMPOSE) --env-file $(INFRA_ENV) -f $(POSTGRES_COMPOSE) down

migrate: infra-up
	$(DOCKER_COMPOSE) --env-file $(API_ENV) -f $(API_COMPOSE) --profile tools run --rm migrator

api-up: network
	$(DOCKER_COMPOSE) --env-file $(API_ENV) -f $(API_COMPOSE) up -d api

api-down:
	-$(DOCKER_COMPOSE) --env-file $(API_ENV) -f $(API_COMPOSE) down

email-up: network
	$(DOCKER_COMPOSE) --env-file $(EMAIL_ENV) -f $(EMAIL_COMPOSE) up -d

email-down:
	-$(DOCKER_COMPOSE) --env-file $(EMAIL_ENV) -f $(EMAIL_COMPOSE) down

metrics-up: network
	$(DOCKER_COMPOSE) --env-file $(METRICS_ENV) -f $(METRICS_COMPOSE) up -d

metrics-down:
	-$(DOCKER_COMPOSE) --env-file $(METRICS_ENV) -f $(METRICS_COMPOSE) down

ping-up: network
	$(DOCKER_COMPOSE) --env-file $(PING_ENV) -f $(PING_COMPOSE) up -d

ping-down:
	-$(DOCKER_COMPOSE) --env-file $(PING_ENV) -f $(PING_COMPOSE) down

state-up: network
	$(DOCKER_COMPOSE) --env-file $(STATE_ENV) -f $(STATE_COMPOSE) up -d

state-down:
	-$(DOCKER_COMPOSE) --env-file $(STATE_ENV) -f $(STATE_COMPOSE) down

tg-bot-up: network
	$(DOCKER_COMPOSE) --env-file $(TG_BOT_ENV) -f $(TG_BOT_COMPOSE) up -d

tg-bot-down:
	-$(DOCKER_COMPOSE) --env-file $(TG_BOT_ENV) -f $(TG_BOT_COMPOSE) down

frontend-up: network
	$(DOCKER_COMPOSE) --env-file $(FRONTEND_ENV) -f $(FRONTEND_COMPOSE) up -d

frontend-down:
	-$(DOCKER_COMPOSE) --env-file $(FRONTEND_ENV) -f $(FRONTEND_COMPOSE) down

services-up: api-up email-up metrics-up ping-up state-up tg-bot-up frontend-up

services-down: frontend-down tg-bot-down state-down ping-down metrics-down email-down api-down

up: infra-up migrate services-up

down: services-down infra-down

ps:
	$(DOCKER_COMPOSE) --env-file $(INFRA_ENV) -f $(POSTGRES_COMPOSE) -f $(REDIS_COMPOSE) -f $(CLICKHOUSE_COMPOSE) -f $(RABBITMQ_COMPOSE) ps
	$(DOCKER_COMPOSE) --env-file $(API_ENV) -f $(API_COMPOSE) ps
	$(DOCKER_COMPOSE) --env-file $(EMAIL_ENV) -f $(EMAIL_COMPOSE) ps
	$(DOCKER_COMPOSE) --env-file $(METRICS_ENV) -f $(METRICS_COMPOSE) ps
	$(DOCKER_COMPOSE) --env-file $(PING_ENV) -f $(PING_COMPOSE) ps
	$(DOCKER_COMPOSE) --env-file $(STATE_ENV) -f $(STATE_COMPOSE) ps
	$(DOCKER_COMPOSE) --env-file $(TG_BOT_ENV) -f $(TG_BOT_COMPOSE) ps
	$(DOCKER_COMPOSE) --env-file $(FRONTEND_ENV) -f $(FRONTEND_COMPOSE) ps

logs:
	$(DOCKER_COMPOSE) --env-file $(INFRA_ENV) -f $(POSTGRES_COMPOSE) -f $(REDIS_COMPOSE) -f $(CLICKHOUSE_COMPOSE) -f $(RABBITMQ_COMPOSE) logs -f --tail=100
