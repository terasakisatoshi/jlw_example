"""Call the Julia-generated Python package from Python.

Run (from the repository root, after `julia --project=. build.jl`):

    python -m venv /tmp/jlw_example-venv
    /tmp/jlw_example-venv/bin/pip install numpy
    PYTHONPATH=out /tmp/jlw_example-venv/bin/python examples/python/demo.py
"""

import numpy as np

from jlw_example_py import escape_time, hello, mandelbrot, scale_inplace


def main() -> None:
    print(hello("Python"))

    a = np.array([1.0, 2.0, 3.0, 4.0])
    scale_inplace(a, factor=0.5)
    print("scale_inplace ->", a)

    print("escape_time(0.5, 0.5) =", escape_time(0.5, 0.5))

    width, height, maxiter = 78, 34, 250
    img = mandelbrot(width, height, maxiter=maxiter)  # shape (height, width), int32
    print(f"\nMandelbrot {width}x{height} (maxiter {maxiter}):")
    ramp = " .:-=+*#%@"
    for row in img:
        line = "".join(
            "@" if n >= maxiter else ramp[n * (len(ramp) - 1) // maxiter]
            for n in row
        )
        print(line)


if __name__ == "__main__":
    main()
