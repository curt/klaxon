VERSION_BASE := $(shell cat VERSION)
VERSION_COMMIT := $(shell git log -1 --format=%H -- VERSION)
PATCH := $(shell git rev-list HEAD ^$(VERSION_COMMIT) --count)
GIT_SHA := $(shell git rev-parse --short HEAD)
FULL_VERSION := $(VERSION_BASE).$(PATCH)+g$(GIT_SHA)
DOCKER_TAG := $(VERSION_BASE).$(PATCH)-g$(GIT_SHA)

APP := klaxon

write-version:
	@echo $(FULL_VERSION) > VERSION.full

print-version:
	@echo $(FULL_VERSION)

build: write-version
	@echo "🔧 Building image for $(APP):$(FULL_VERSION)..."
	VERSION=$(FULL_VERSION) DOCKER_TAG=$(DOCKER_TAG) docker-compose build
	@echo "🏷 Tagging $(APP):$(DOCKER_TAG) as $(APP):latest..."
	docker tag $(APP):$(DOCKER_TAG) $(APP):latest

up:
	@echo "🚀 Starting containers for $(APP):$(shell cat VERSION.full)..."
	VERSION=$(shell cat VERSION.full) DOCKER_TAG=$(DOCKER_TAG) docker-compose up -d

# Convenience target: build and start containers
up-build: build up

down:
	docker-compose down

clean:
	docker-compose down
	docker system prune -f

reset: down clean
	@rm -f VERSION.full

status:
	docker-compose ps

logs:
	docker-compose logs -f

logs-app:
	docker-compose logs -f app

tag:
	@git tag -a v$(FULL_VERSION) -m "Release v$(FULL_VERSION)"
	@git push origin v$(FULL_VERSION)
