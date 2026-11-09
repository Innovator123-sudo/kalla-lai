SHELL := /bin/sh
COMPOSE := docker compose

.PHONY: install api-dev api-test api-build web-test web-analyze web-build \
        up down logs ps seed migrate backup monitoring smoke openapi test

install:
	cd server && npm ci
	flutter pub get

api-dev:
	cd server && npm run dev

api-test:
	cd server && npm run typecheck && npm test

api-build:
	cd server && npm run build

web-analyze:
	flutter analyze

web-test:
	flutter test

web-build:
	flutter build web --release --no-web-resources-cdn \
		--dart-define=KALLALAI_API_URL=

up:
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f --tail=200

ps:
	$(COMPOSE) ps

seed:
	$(COMPOSE) --profile tools run --rm seed

migrate:
	$(COMPOSE) exec api node dist/db/migrate.js

backup:
	$(COMPOSE) --profile tools run --rm backup

monitoring:
	$(COMPOSE) --profile monitoring up -d prometheus grafana

smoke:
	cd server && API_BASE_URL=http://127.0.0.1:8090 npm run smoke

openapi:
	python3 -c "import json; json.load(open('server/openapi.json'))"
