# Convenience wrapper for the Dockerfiles in this directory.
#
# Run from anywhere; the build context is the repository root.
#
#   make -C docker build          # build the shared-library + Python package
#   make -C docker all            # build every image (build image first)
#   make -C docker python         # build one runtime image
#   make -C docker run-cpp        # run one runtime image
#   make -C docker run-all        # run every runtime image
#
# Override the image name prefix or Docker binary:
#   make -C docker TAG=myrepo/jlw DOCKER="docker buildx" all

DOCKER ?= docker
TAG ?= jlw_example
CONTEXT ?= ..

BUILD_IMAGE := $(TAG)-build:latest

LANGS := python cpp fortran rust bundle

# NOTE: the run-* targets are pattern targets and must NOT be listed as
# .PHONY, or GNU make skips the implicit rule search and does nothing.
.PHONY: all build run-all clean $(LANGS)

all: build $(LANGS)

build:
	$(DOCKER) build -f Dockerfile.build -t $(BUILD_IMAGE) $(CONTEXT)

$(LANGS): build
	$(DOCKER) build -f Dockerfile.$@ \
		--build-arg BUILD_IMAGE=$(BUILD_IMAGE) \
		-t $(TAG)-$@ $(CONTEXT)

run-all: all $(addprefix run-,$(LANGS))

run-%:
	$(DOCKER) run --rm $(TAG)-$*

clean:
	-$(DOCKER) image rm -f $(BUILD_IMAGE) $(addprefix $(TAG)-,$(LANGS))
