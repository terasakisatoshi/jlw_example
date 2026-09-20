#!/usr/bin/env bash
# Build the Julia library and run every language demo.
#
# Usage: ./run_all.sh
set -euo pipefail

cd "$(dirname "$0")"

case "$(uname -s)" in
    Darwin) LIBEXT=dylib ;;
    *)      LIBEXT=so ;;
esac
LIB="out/jlw_example.${LIBEXT}"
VENV="${TMPDIR:-/tmp}/jlw_example-venv"

echo "==> Resolving Julia environments"
julia --project=build-env -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.instantiate()'

echo "==> Building the shared library, C header and Python package"
julia --project=. build.jl

echo
echo "==> Python"
if [ ! -x "${VENV}/bin/python" ]; then
    python3 -m venv "${VENV}"
fi
"${VENV}/bin/pip" install -q numpy
PYTHONPATH=out "${VENV}/bin/python" examples/python/demo.py

echo
echo "==> C++"
c++ -std=c++17 -Iout examples/cpp/demo.cpp "${LIB}" \
    -Wl,-rpath,"${PWD}/out" -o examples/cpp/demo
./examples/cpp/demo

echo
echo "==> Fortran"
gfortran examples/fortran/demo.f90 "${LIB}" \
    -Jexamples/fortran \
    -Wl,-rpath,"${PWD}/out" -o examples/fortran/demo
./examples/fortran/demo

echo
echo "==> Rust"
cargo run --quiet --manifest-path examples/rust/Cargo.toml

echo
echo "All demos ran successfully."
