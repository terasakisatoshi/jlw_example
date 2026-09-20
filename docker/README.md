# Docker images for jlw_example

Runtime images for each language binding, plus a separate build image that
produces the shared library and the generated Python package.

All builds run on Linux (`jlw_example.so`), so the language demos use the `.so`
name instead of the `.dylib` used on macOS. Only the build image compiles
Julia, so it is the slow one; the language images only add a toolchain and run
a demo.

## Build everything with make

The included `Makefile` builds the base image first and then the runtime
images, so the required ordering is handled for you:

```
make -C docker all        # build the base image and every runtime image
make -C docker run-all    # build everything, then run each image
make -C docker run-cpp    # run a single runtime image
make -C docker clean      # remove the images
```

`TAG` changes the image name prefix (`make -C docker TAG=myrepo/jlw all`) and
`DOCKER` selects a different client (`make -C docker DOCKER="docker buildx" all`).

## Build image

```
docker build -f docker/Dockerfile.build -t jlw_example-build .
```

`jlw_example-build` contains `/app/out` (library, C header, ABI metadata and the
`jlw_example_py` package). It is the base for every runtime image below and
must be built first. Skip this manual step if you use `make`.

## Per-language runtime images

Each command builds on top of `jlw_example-build` and runs the corresponding
demo when started.

| Language | Build | Run |
| --- | --- | --- |
| Python | `docker build -f docker/Dockerfile.python -t jlw_example-python .` | `docker run --rm jlw_example-python` |
| C++ | `docker build -f docker/Dockerfile.cpp -t jlw_example-cpp .` | `docker run --rm jlw_example-cpp` |
| Fortran | `docker build -f docker/Dockerfile.fortran -t jlw_example-fortran .` | `docker run --rm jlw_example-fortran` |
| Rust | `docker build -f docker/Dockerfile.rust -t jlw_example-rust .` | `docker run --rm jlw_example-rust` |
| Bundle | `docker build -f docker/Dockerfile.bundle -t jlw_example-bundle .` | `docker run --rm jlw_example-bundle` |

`Dockerfile.bundle` is a two-stage build: it produces `out-bundle/` in the
build image, then installs it into a plain `python:3.11-slim` image that has no
Julia. Running it prints `Hello, world`, which verifies the Julia-independent
distribution path.

`Dockerfile.rust` compiles the demo in a throwaway stage and copies only the
resulting binary into the final image, so the Rust toolchain is not shipped. The
final image is the same size as the build image.

## Custom build image locations

The runtime Dockerfiles accept a `BUILD_IMAGE` argument, so a base image from a
registry can be used instead of a local tag:

```
docker build -f docker/Dockerfile.python \
    --build-arg BUILD_IMAGE=registry.example.com/jlw_example-build:latest \
    -t jlw_example-python .
```

`Dockerfile.rust` additionally accepts `RUST_IMAGE` (default
`rust:1.98.1-bookworm`).

## Notes

- Run `docker build` from the repository root; the build context and
  `.dockerignore` are defined there.
- The non-bundle library keeps a dependency on the Julia runtime. Deriving the
  runtime images from `jlw_example-build` guarantees the Julia prefix is the
  same as at link time, so no `LD_LIBRARY_PATH` is needed.
- The bundle image is the only one that does not need Julia at run time.
