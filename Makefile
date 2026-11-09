# KD기공 ERP — 개발 명령 모음
# `make check` 가 통과해야 작업 완료 (사람/AI 공통)

SHELL := /bin/bash
HAS_GO  := $(shell test -f go.mod && echo yes)
HAS_WEB := $(shell test -f web/package.json && echo yes)

.PHONY: check fmt vet lint test arch web-check sqlc migrate-new

check: fmt vet lint test arch web-check
	@echo "✅ make check 전체 통과"

fmt:
ifeq ($(HAS_GO),yes)
	@out="$$(gofmt -l ./cmd ./internal 2>/dev/null)"; \
	if [ -n "$$out" ]; then echo "❌ gofmt 필요:"; echo "$$out"; exit 1; fi
else
	@echo "ℹ️  go.mod 없음 — fmt 건너뜀"
endif

vet:
ifeq ($(HAS_GO),yes)
	go vet ./...
else
	@echo "ℹ️  go.mod 없음 — vet 건너뜀"
endif

lint:
ifeq ($(HAS_GO),yes)
	@if command -v golangci-lint >/dev/null; then golangci-lint run ./...; \
	else echo "⚠️  golangci-lint 미설치 — brew install golangci-lint"; fi
else
	@echo "ℹ️  go.mod 없음 — lint 건너뜀"
endif

test:
ifeq ($(HAS_GO),yes)
	go test -race -count=1 ./...
else
	@echo "ℹ️  go.mod 없음 — test 건너뜀"
endif

arch:
	@bash scripts/check-arch.sh

web-check:
ifeq ($(HAS_WEB),yes)
	cd web && npm run typecheck && npm run lint && npm test -- --run
else
	@echo "ℹ️  web/package.json 없음 — web-check 건너뜀"
endif

sqlc:
	sqlc generate

migrate-new:
	@test -n "$(name)" || (echo "사용법: make migrate-new name=create_project"; exit 1)
	goose -dir db/migrations create $(name) sql
