# jlw_example

An example of using [JuliaLibWrapping.jl](https://github.com/JuliaInterop/JuliaLibWrapping.jl) (JLW) to turn Julia code into a shared library and call it from Python, C++, Fortran, and Rust. It demonstrates drawing the Mandelbrot set and passing strings, scalars, and arrays across the language boundary.

## Quick demo

These commands cover cloning the repository and running all features: Python, C++, Fortran, Rust, and the Julia-independent bundle. Choose either the local or Docker route. To try both, use a different clone destination for the second route, as shown in the Docker example.

### Run locally

You need Julia 1.13 or later, a C++ compiler, gfortran, cargo, Python 3, and NumPy (see [Requirements](#requirements)).

```sh
git clone https://github.com/terasakisatoshi/jlw_example.git
cd jlw_example
./run_all.sh
```

`run_all.sh` builds the shared library and Python package, then runs the Python, C++, Fortran, and Rust demos in order. The run succeeds when it ends with `All demos ran successfully.`

Next, try the Julia-independent distribution package:

```sh
julia --project=. build_bundle.jl
python3 -m venv /tmp/jlw_bundle-venv
/tmp/jlw_bundle-venv/bin/pip install ./out-bundle
/tmp/jlw_bundle-venv/bin/python -c 'from jlw_example_py import hello; print(hello("world"))'
```

### Run with Docker

Use Docker to try the examples without installing Julia or the language toolchains locally (see [Docker](#docker)). Docker and `make` are required.

```sh
git clone https://github.com/terasakisatoshi/jlw_example.git jlw_example-docker
cd jlw_example-docker
make -C docker run-all
```

This builds the build image, then builds and runs the Python, C++, Fortran, Rust, and bundle images.

## What this example demonstrates

The examples cover the main JLW boundary conventions:

- Pass a Julia `String` as a Python `str` or a C `CString_owned`.
- Pass `Int` and `Float64` scalars directly.
- Return a `Matrix{Int32}` as an owned array and read its Julia column-major data from the caller.
- Pass a `Vector{Float64}` as a borrowed array and observe Julia's changes from the caller.

JLW generates the Python wrapper. It does not generate bindings for C++, Fortran, or Rust, so those examples use the generated C header `out/jlw_example.h` directly.

## Requirements

- Julia 1.13 or later
- JLWInterop 0.2, JuliaLibWrapping 0.2, and JuliaC 0.3 (installed by `Pkg.instantiate`)
- A C++ compiler, gfortran, cargo, Python 3, and NumPy

## Build and run

To run everything at once:

```sh
./run_all.sh
```

To build manually, follow these three steps:

```sh
julia --project=build-env -e 'using Pkg; Pkg.instantiate()'   # Build tools
julia --project=. -e 'using Pkg; Pkg.instantiate()'           # Library runtime dependencies
julia --project=. build.jl                                    # Generate the shared library and wrapper
```

`build.jl` calls `build_library` with `bundle = false`. The generated library refers to the build machine's `libjulia`, so Julia must be available in the runtime environment. To create a standalone distribution package, use `bundle = true` and `privatize` (see [Bundling for distribution](https://juliainterop.github.io/JuliaLibWrapping.jl/stable/building/#Bundling-for-distribution)).

After building, `out/` has the following structure:

```
out/
├── jlw_example.dylib        # Shared library (.so on Linux)
├── jlw_example.h            # C header
├── jlw_example.abi.json     # ABI information emitted by juliac
├── jlw_example.jlw.json     # Metadata for @api declarations
├── pyproject.toml
└── jlw_example_py/          # Python package
    ├── __init__.py
    ├── _facade.py           # Editable thin wrapper
    └── _lowlevel.py         # Mechanical ctypes bindings
```

`build.jl` copies the shared library to `out/jlw_example_py/` immediately after generation because the generated Python loader looks for the library in the package directory.

### Julia-independent distribution package

Use `build_bundle.jl` to distribute the package to environments without Julia:

```sh
julia --project=. build_bundle.jl
```

This calls `standard_build` with its default `bundle = true` and generates `out-bundle/`. The Julia runtime is included in `out-bundle/jlw_example_py/bundle/lib/`, and `libjulia` is privatized. Privatization (`privatize`) rewrites shared-library install names relative to `@loader_path`, so the bundled runtime can be found without setting environment variables. The generated Python loader also searches `bundle/lib` before the package root. The package is tens of megabytes larger, but works with just `pip install`.

```sh
python3 -m venv /tmp/jlw_bundle-venv
/tmp/jlw_bundle-venv/bin/pip install ./out-bundle
/tmp/jlw_bundle-venv/bin/python -c 'from jlw_example_py import hello; print(hello("world"))'
```

The last command prints `Hello, world`, even if Julia is not on `PATH`.

The main contents of `out-bundle/` are shown below. The runtime is in `jlw_example_py/bundle/lib/`.

```
out-bundle/
├── jlw_example_py/
│   ├── _facade.py
│   ├── _lowlevel.py
│   └── bundle/
│       └── lib/              # Privatized libjulia and its dependencies
│           ├── <hash>_libjulia*.dylib
│           ├── jlw_example.dylib
│           └── julia/
├── jlw_example.h
├── jlw_example.abi.json
├── jlw_example.jlw.json
└── pyproject.toml
```

Because `pyproject.toml` depends on `numpy>=1.20`, access to PyPI is still required in an environment without Julia. For fully offline distribution, prepare the wheels in advance.

The C++, Fortran, and Rust demos expect the library in `out/`.

## Public API

The `@api` declarations in `src/jlw_example.jl` define the externally visible boundary. `@export_release_entrypoints` emits `jlw_free` for freeing owned return values; it is required for APIs that return strings or arrays.

| Julia function | Arguments | Return value | Generated C function |
| --- | --- | --- | --- |
| `hello(who)` | `String` | `String` | `jlw_example_hello` |
| `escape_time(cx, cy; maxiter)` | `Float64`, `Float64`, `Int` | `Int` | `jlw_example_escape_time` |
| `mandelbrot(width, height; maxiter)` | `Int`, `Int`, `Int` | `Matrix{Int32}` | `jlw_example_mandelbrot` |
| `scale_inplace(a; factor)` | `Vector{Float64}`, `Float64` | `Nothing` | `jlw_example_scale_inplace` |

C function names are qualified with the declaring module's name. The language wrappers use those qualified names directly.

## Language-specific notes

### Python

The generated `_facade.py` handles NumPy arrays and `str`. `mandelbrot` returns an `int32` array of shape `(height, width)` and frees the owned return value in a `finally` block.

```sh
python3 -m venv /tmp/jlw_example-venv
/tmp/jlw_example-venv/bin/pip install numpy
PYTHONPATH=out /tmp/jlw_example-venv/bin/python examples/python/demo.py
```

`demo.py` first prints `Hello, Python`, followed by `scale_inplace -> [0.5 1.  1.5 2. ]` and `escape_time(0.5, 0.5) = 5`, and finally draws the Mandelbrot set in text.

Since `out/` also contains `pyproject.toml`, you can install it as a package instead (`numpy` is installed automatically as a dependency):

```sh
/tmp/jlw_example-venv/bin/pip install ./out
/tmp/jlw_example-venv/bin/python examples/python/demo.py
```

### C++

The generated header uses C linkage, so include it within `extern "C"` in C++. Otherwise, symbol names are mangled and linking fails. APIs that return strings or matrices return owned values, so call `jlw_free(value.data)` after using `JLWResult_*.value` (see `examples/cpp/demo.cpp`).

```sh
c++ -std=c++17 -Iout examples/cpp/demo.cpp out/jlw_example.dylib \
    -Wl,-rpath,$PWD/out -o examples/cpp/demo && ./examples/cpp/demo
```

`demo` prints `Hello, C++`, `scale_inplace -> 0.50 1.00 1.50 2.00`, and `escape_time(0.5, 0.5) = 5`, then draws the Mandelbrot set in text.

### Fortran

Use `iso_c_binding` to mirror the structure layouts. The array returned by `mandelbrot` is column-major, like Julia, so it can be read directly as an array of shape `(height, width)` using `c_f_pointer`. Call `jlw_free` to free strings and matrices.

```sh
gfortran examples/fortran/demo.f90 out/jlw_example.dylib \
    -Wl,-rpath,$PWD/out -o examples/fortran/demo && ./examples/fortran/demo
```

`gfortran` must support C functions that return structures by value (verified with GCC 8 and later). `demo` prints `Hello, C++`, `scale_inplace -> 0.50  1.00  1.50  2.00`, and `escape_time(0.5, 0.5) = 5`.

### Rust

Define the ABI structures with `#[repr(C)]` and pass the library path and `rpath` to the linker from `build.rs`. Because the shared library name has no `lib` prefix, the path is passed directly instead of using `-l`.

```sh
cargo run --manifest-path examples/rust/Cargo.toml
```

`examples/rust/Cargo.toml` uses edition 2021. `cargo run` prints `Hello, Rust`, `scale_inplace -> [0.5, 1.0, 1.5, 2.0]`, and `escape_time(0.5, 0.5) = 5`.

## Boundary conventions

Arrays are **column-major**. Read element `(i, j)` as `data[i + j*rows]`. A returned matrix has dimensions in the order `dims = (rows, cols) = (height, width)`. For example, `mandelbrot(3, 2)` returns `dims = (2, 3)` and a `data` array of length 6; zero-based `data[i + j*rows]` corresponds to the one-based element `(i+1, j+1)`. NumPy defaults to row-major order, so use `np.asfortranarray` when passing N-dimensional arrays (this example only passes a one-dimensional array).

Array arguments are **borrowed**: the caller owns their memory, and changes made by Julia are visible to the caller. Returned arrays and strings are **owned**: the caller must free the copies allocated by the library using `jlw_free`.

Errors are reported through `JLWStatus.code`. A `code` of zero indicates success; otherwise, `message` contains the exception message. In Python, errors are raised as `JLWError`.

## Docker

The `docker/` directory contains a build image for generating the shared library and runtime images for each language. The build image is the only one that compiles Julia; the runtime images add toolchains on top of it and run the demos. The `Makefile` handles the build order (build image first, then each language).

```sh
make -C docker all        # Build the build image and all language images
make -C docker run-all    # Build and run each image
```

To run the steps manually:

```sh
docker build -f docker/Dockerfile.build -t jlw_example-build .
docker build -f docker/Dockerfile.python -t jlw_example-python .
docker run --rm jlw_example-python
```

There are five runtime Dockerfiles: `Dockerfile.python`, `Dockerfile.cpp`, `Dockerfile.fortran`, `Dockerfile.rust`, and `Dockerfile.bundle`. Only `Dockerfile.bundle` installs `out-bundle/` into a `python` image without Julia, verifying that it works without Julia. See `docker/README.md` for details and for overriding `BUILD_IMAGE` / `RUST_IMAGE`. Docker uses Linux, so the shared library is named `jlw_example.so`.

## File layout

```
jlw_example/
├── Project.toml            # Runtime dependency (JLWInterop)
├── build-env/Project.toml  # Build tools (JuliaC, JuliaLibWrapping)
├── build.jl                # Calls build_library
├── build_bundle.jl         # Julia-independent distribution (bundle = true)
├── run_all.sh              # Builds and runs all languages
├── src/jlw_example.jl      # @api declarations and implementation
├── docker/                 # Build and language-specific Dockerfiles
│   ├── Dockerfile.build
│   ├── Dockerfile.python
│   ├── Dockerfile.cpp
│   ├── Dockerfile.fortran
│   ├── Dockerfile.rust
│   ├── Dockerfile.bundle
│   └── README.md
└── examples/
    ├── python/demo.py
    ├── cpp/demo.cpp
    ├── fortran/demo.f90
    └── rust/{Cargo.toml,build.rs,src/main.rs}
```
