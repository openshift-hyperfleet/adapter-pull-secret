.DEFAULT_GOAL := help

# CGO_ENABLED=0 for static binary (MVP simplified build)
# Set to 1 for FIPS compliance in production if needed
CGO_ENABLED := 0
GOPATH ?= $(shell go env GOPATH)

# Image version - uses timestamp for uniqueness
version := $(shell date +%s)

# Go version
GO_VERSION := go1.23.9

# Container image configuration
# Override these via environment variables if needed:
# - IMAGE_REGISTRY: Container registry (default: quay.io)
# - IMAGE_REPOSITORY: Repository path (default: hyperfleet/pull-secret)
# - IMAGE_TAG: Image tag (default: timestamp-based version)
IMAGE_REGISTRY ?= quay.io
IMAGE_REPOSITORY ?= hyperfleet/pull-secret
IMAGE_TAG ?= $(version)
IMAGE_FULL = $(IMAGE_REGISTRY)/$(IMAGE_REPOSITORY):$(IMAGE_TAG)

# Enable Go modules
export GOPROXY=https://proxy.golang.org
export GOPRIVATE=gitlab.cee.redhat.com

####################
# Help
####################

help:
	@echo ""
	@echo "HyperFleet MVP - Pull Secret Job"
	@echo ""
	@echo "Build Targets:"
	@echo "  make binary               compile pull-secret binary"
	@echo "  make image                build container image"
	@echo "  make push                 push container image to quay.io"
	@echo "  make clean                delete temporary generated files"
	@echo ""
	@echo "Examples:"
	@echo "  make binary"
	@echo "  make image IMAGE_TAG=v1.0.0"
	@echo "  make push IMAGE_REGISTRY=quay.io IMAGE_REPOSITORY=myorg/pull-secret"
	@echo ""
.PHONY: help

####################
# Build Targets
####################

# Checks if a GOPATH is set, or emits an error message
check-gopath:
ifndef GOPATH
	$(error GOPATH is not set)
endif
.PHONY: check-gopath

# Build pull-secret binary
# CGO_ENABLED=0 produces a static binary (no libc dependency)
binary: check-gopath
	@echo "Building pull-secret binary..."
	CGO_ENABLED=$(CGO_ENABLED) go build \
		-o pull-secret \
		./cmd/pull-secret
	@echo "Binary built: ./pull-secret"
	@go version | grep -q "$(GO_VERSION)" || \
		( \
			printf '\033[41m\033[97m\n'; \
			echo "* WARNING: Your go version is not the expected $(GO_VERSION) *" | sed 's/./*/g'; \
			echo "* WARNING: Your go version is not the expected $(GO_VERSION) *"; \
			echo "* WARNING: Your go version is not the expected $(GO_VERSION) *" | sed 's/./*/g'; \
			printf '\033[0m\n'; \
		)
.PHONY: binary

####################
# Container Image Targets
####################

# Build container image using podman
# Uses multi-stage Dockerfile for optimized image size
#
# Examples:
#   make image
#   make image IMAGE_TAG=v1.0.0
#   make image IMAGE_REGISTRY=quay.io IMAGE_REPOSITORY=myorg/pull-secret-mvp
image:
	@echo "Building container image..."
	@echo "Image: $(IMAGE_FULL)"
	podman build -t "$(IMAGE_FULL)" -f Dockerfile .
	@echo ""
	@echo "Image built successfully: $(IMAGE_FULL)"
	@echo ""
	@echo "To run locally:"
	@echo "  podman run --rm -e GCP_PROJECT_ID=your-project -e CLUSTER_ID=cls-123 $(IMAGE_FULL)"
	@echo ""
.PHONY: image

# Push container image to registry (quay.io by default)
# Requires authentication: podman login $(IMAGE_REGISTRY)
#
# Examples:
#   make push
#   make push IMAGE_TAG=v1.0.0
#   make push IMAGE_REGISTRY=quay.io IMAGE_REPOSITORY=hyperfleet/pull-secret-mvp
push: image
	@echo "Pushing image to registry..."
	@echo "Image: $(IMAGE_FULL)"
	podman push "$(IMAGE_FULL)"
	@echo ""
	@echo "Image pushed successfully!"
	@echo "Pull with: podman pull $(IMAGE_FULL)"
	@echo ""
.PHONY: push

####################
# Clean
####################

# Delete temporary files and build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f pull-secret
	rm -f *.exe *.dll *.so *.dylib
	@echo "Clean complete."
.PHONY: clean
