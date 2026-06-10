.PHONY: help validate generate sync-configs up down systemd-install systemd-uninstall backup restore

# Default target
help:
	@echo "AzerothCore Environment Management"
	@echo ""
	@echo "Available targets:"
	@echo "  validate          - Validate .env configuration"
	@echo "  generate          - Generate docker-compose.override.yml from template"
	@echo "  sync-configs      - Sync module .conf files from latest .conf.dist"
	@echo "  up                - Generate configs and start containers"
	@echo "  down              - Stop containers"
	@echo "  systemd-install   - Install systemd services"
	@echo "  systemd-uninstall - Remove systemd services"
	@echo "  backup            - Run database backup"
	@echo "  restore           - Run database restore"

validate:
	@./scripts/validate-env.sh

generate: validate
	@./scripts/generate-configs.sh

sync-configs:
	@python3 ./scripts/sync-module-configs.py

up: generate
	@echo "Starting containers..."
	@bash -c 'source .env && if [ "$${AUTHSERVER_PROFILE}" = "default" ]; then docker compose --profile default up -d; else docker compose up -d; fi'

down:
	@echo "Stopping containers..."
	@docker compose down

systemd-install:
	@./scripts/install-systemd-services.sh

systemd-uninstall:
	@./scripts/uninstall-systemd-services.sh

backup:
	@./scripts/backup-databases.sh

restore:
	@./scripts/restore-databases.sh
