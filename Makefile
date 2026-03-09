.PHONY: up down backend admin mobile fmt

up:
	docker compose up -d postgres redis meilisearch

down:
	docker compose down

backend:
	cd backend && uvicorn app.main:app --reload

admin:
	cd admin && npm run dev

mobile:
	cd mobile && flutter run

fmt:
	cd backend && ruff check .
