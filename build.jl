push!(LOAD_PATH, joinpath(@__DIR__, "build-env"))
using JuliaLibWrapping, JuliaC

const OUT = joinpath(@__DIR__, "out")

result = build_library(
    joinpath(@__DIR__, "src", "jlw_example.jl"),
    [
        CTarget(OUT, "jlw_example"),
        PythonTarget(OUT, "jlw_example_py", "jlw_example"),
    ];
    project = @__DIR__,
    libname = "jlw_example",
    libdir = OUT,
    bundle = false,
    verbose = true,
)

# The generated Python loader looks for the shared library next to the
# package directory, so place a copy there for the in-repo examples.
cp(result.library, joinpath(OUT, "jlw_example_py", basename(result.library));
   force = true)

@info "Build finished" result.library result.target_outputs result.metadata_path

pop!(LOAD_PATH)
