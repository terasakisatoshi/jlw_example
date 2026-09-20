# syntax=docker/dockerfile:1
#
# Runtime image for the C++ binding.
#
# Compiles and runs examples/cpp/demo.cpp against the prebuilt shared library
# in /app/out, mirroring the command documented in README.md.
#
# Build the base image first:
#   docker build -f docker/Dockerfile.build -t jlw_example-build .
# Then:
#   docker build -f docker/Dockerfile.cpp -t jlw_example-cpp .
#   docker run --rm jlw_example-cpp
#
# Override BUILD_IMAGE for a different build image or registry path.

ARG BUILD_IMAGE=jlw_example-build:latest
FROM ${BUILD_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends g++ \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

CMD ["sh", "-c", "c++ -std=c++17 -Iout examples/cpp/demo.cpp out/jlw_example.so -Wl,-rpath,/app/out -o /tmp/demo && /tmp/demo"]
