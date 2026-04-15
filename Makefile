.DEFAULT_GOAL := help
IMAGE_NAME    := audiodrop
RECORDINGS    := $(shell pwd)/recordings

.PHONY: help build run stop logs list-devices clean

## help: Show this help message
help:
	@echo ""
	@echo "AudioDrop – Makefile targets"
	@echo "────────────────────────────"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""

## build: Build the Docker image
build:
	docker build -t $(IMAGE_NAME) .

## run: Start the container (uses .env if present)
run:
	@mkdir -p $(RECORDINGS)
	docker compose up -d
	@echo "Recording to $(RECORDINGS). Run 'make logs' to follow output."

## stop: Stop and remove the container
stop:
	docker compose down

## logs: Follow container logs
logs:
	docker compose logs -f

## list-devices: List available ALSA capture devices
list-devices:
	docker run --rm \
		--device /dev/snd:/dev/snd \
		--group-add audio \
		-e AUDIO_DEVICE=list \
		$(IMAGE_NAME)

## clean: Remove stopped container and the local image
clean: stop
	docker rmi $(IMAGE_NAME) 2>/dev/null || true
