module jlw_example

using JLWInterop

@export_release_entrypoints

"Return a greeting for `who`."
hello(who::String) = "Hello, $who"

@api hello(who::String)::String

"""
    escape_time(cx, cy; maxiter = 100)

Return the number of iterations before the quadratic map `z ← z² + c`, with
`c = cx + im*cy`, escapes (`|z| > 2`). The count is capped at `maxiter`; a
point that never escapes (believed to be in the Mandelbrot set) yields
`maxiter`.
"""
function escape_time(cx::Float64, cy::Float64; maxiter::Int = 100)
    zx = 0.0
    zy = 0.0
    n = 0
    while n < maxiter && zx * zx + zy * zy <= 4.0
        zx, zy = zx * zx - zy * zy + cx, 2.0 * zx * zy + cy
        n += 1
    end
    return n
end

@api escape_time(cx::Float64, cy::Float64; maxiter::Int = 100)::Int

"""
    mandelbrot(width, height; maxiter = 100)

Render the Mandelbrot set over `[-2, 0.5] × [-1.25, 1.25]` into a
`height × width` matrix of escape times (returned in Julia column-major order).
"""
function mandelbrot(width::Int, height::Int; maxiter::Int = 100)
    img = Matrix{Int32}(undef, height, width)
    for j in 1:width
        cx = -2.0 + 2.5 * (j - 0.5) / width
        for i in 1:height
            cy = -1.25 + 2.5 * (i - 0.5) / height
            img[i, j] = Int32(escape_time(cx, cy; maxiter = maxiter))
        end
    end
    return img
end

@api mandelbrot(width::Int, height::Int; maxiter::Int = 100)::Matrix{Int32}

"""
    scale_inplace(a; factor = 2.0)

Multiply every element of `a` by `factor` in place. Returns `nothing`; the
mutation is visible to the caller because array arguments are borrowed views.
"""
function scale_inplace(a::Vector{Float64}; factor::Float64 = 2.0)
    a .*= factor
    return nothing
end

@api scale_inplace(a::Vector{Float64}; factor::Float64 = 2.0)::Nothing

end # module jlw_example
