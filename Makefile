.PHONY: up down build logs restart

# Start the full stack in the background (detached)
up:
	docker compose up -d --build

down:
	docker compose down

build:
	docker compose build

logs:
	docker compose logs -f

restart: down up
