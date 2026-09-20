push!(LOAD_PATH, joinpath(@__DIR__, "build-env"))
using JuliaLibWrapping, JuliaC

# Same library, but with a self-contained julia runtime closure copied into
# the Python package (`out-bundle/jlw_example_py/bundle/`). The resulting
# wheel installs on a machine without Julia.
standard_build(
    @__DIR__;
    libname = "jlw_example",
    out = joinpath(@__DIR__, "out-bundle"),
    verbose = true,
)

pop!(LOAD_PATH)
