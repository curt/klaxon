ifneq (,$(wildcard .env))
  include .env
  export
endif

VERSION_BASE := $(shell cat VERSION)
VERSION_COMMIT := $(shell git log -1 --format=%H -- VERSION)
PATCH := $(shell git rev-list HEAD ^$(VERSION_COMMIT) --count)
GIT_SHA := $(shell git rev-parse --short HEAD)
FULL_VERSION := $(VERSION_BASE).$(PATCH)+g$(GIT_SHA)
DOCKER_TAG := $(VERSION_BASE).$(PATCH)-g$(GIT_SHA)
VERSION := $(FULL_VERSION)
APP := klaxon

ARCH := $(shell uname -m)
ARCH := $(if $(findstring aarch64,$(ARCH)),arm64,$(ARCH))

ifeq ($(ARCH),x86_64)
  POSTGIS_IMAGE_NAME := postgis/postgis
else ifeq ($(ARCH),arm64)
  POSTGIS_IMAGE_NAME := ghcr.io/curt/postgis
else
  $(error Unsupported architecture: $(ARCH))
endif

require-env-var = \
  if [ -z "$${$(1)}" ]; then \
    echo "Error: Environment variable '$(1)' is not set."; \
    exit 1; \
  fi

export POSTGIS_IMAGE_NAME DOCKER_TAG VERSION

write-version:
	@echo $(FULL_VERSION) > VERSION.full

print-version:
	@echo $(FULL_VERSION)

require-compose-env:
	@$(call require-env-var,KLAXON_PORT)
	@$(call require-env-var,POSTGRES_PORT)
	@$(call require-env-var,POSTGRES_PASSWORD)

require-s3-env:
	@$(call require-env-var,AWS_ACCESS_KEY_ID)
	@$(call require-env-var,AWS_SECRET_ACCESS_KEY)
	@$(call require-env-var,AWS_REGION)
	@$(call require-env-var,AWS_S3_DUMP_BUCKET)

pull-db: require-compose-env
	@echo "🔄 Pulling image for $(POSTGIS_IMAGE_NAME)..."
	docker compose pull db

up-db: require-compose-env
	@echo "🚀 Starting container for $(POSTGIS_IMAGE_NAME)..."
	docker compose up db -d

build: require-compose-env write-version
	@echo "🔧 Building image for $(APP):$(FULL_VERSION)..."
	docker compose build
	@echo "🏷 Tagging $(APP):$(DOCKER_TAG) as $(APP):latest..."
	docker tag $(APP):$(DOCKER_TAG) $(APP):latest

up: require-compose-env require-s3-env
	@echo "🚀 Starting containers for $(APP)..."
	VERSION=$(shell cat VERSION.full) docker compose up -d

up-build: build up

stop-app: require-compose-env
	@echo "🛑 Stopping the container for $(APP)..."
	docker compose stop app

down: require-compose-env
	@echo "🛑 Stopping and removing containers for $(APP)..."
	docker compose down

clean: down
	@echo "🧹 Removing unused Docker resources..."
	docker system prune -f

reset: down clean
	@rm -f VERSION.full

status: require-compose-env
	docker compose ps

logs: require-compose-env
	docker compose logs -f

logs-app: require-compose-env
	docker compose logs -f app

tag:
	@git tag -a v$(FULL_VERSION) -m "Release v$(FULL_VERSION)"
	@git push origin v$(FULL_VERSION)

dump-db: require-compose-env require-s3-env
	@timestamp=$$(date +%Y%m%d-%H%M%S); \
	container_name=$$(docker compose ps -q db | xargs docker inspect --format '{{.Name}}' | sed 's|/||'); \
	short_hostname=$$(hostname | cut -d. -f1); \
	filename="db-dump-$$short_hostname-$$container_name-$$timestamp.sql.gz"; \
	echo "Dumping and compressing database to $$filename..."; \
	docker compose exec -T db \
	  env PGPASSWORD=$$POSTGRES_PASSWORD \
	  pg_dump -U klaxon klaxon \
	  | gzip > $$filename; \
	echo "Uploading $$filename to s3://$$AWS_S3_DUMP_BUCKET/"; \
	aws s3 cp $$filename s3://$$AWS_S3_DUMP_BUCKET/; \
	rm $$filename; \
	echo "✅ Backup complete: $$filename uploaded and removed locally."
