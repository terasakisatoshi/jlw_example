// Call the Julia-generated shared library from C++.
//
// Build (from the repository root, after `julia --project=. build.jl`):
//   c++ -std=c++17 -Iout examples/cpp/demo.cpp out/jlw_example.dylib \
//       -Wl,-rpath,$(pwd)/out -o examples/cpp/demo
//
// On Linux replace `out/jlw_example.dylib` with `out/jlw_example.so`.

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

// The generated header has C linkage; guard it for C++ name mangling.
extern "C" {
#include "jlw_example.h"
}

static void check(const JLWStatus &status, const char *what) {
    if (status.code != 0) {
        std::fprintf(stderr, "%s failed [%d]: %s\n", what, status.code,
                     reinterpret_cast<const char *>(status.message));
        std::exit(1);
    }
}

int main() {
    // --- String crossing the boundary (owning return, released by us) -------
    {
        std::string who = "C++";
        CString_borrowed arg{static_cast<int64_t>(who.size()),
                             reinterpret_cast<uint8_t *>(who.data())};
        JLWResult_CString_owned r = jlw_example_hello(arg);
        check(r.status, "hello");
        std::printf("%.*s\n", static_cast<int>(r.value.length),
                    reinterpret_cast<const char *>(r.value.data));
        jlw_free(r.value.data); // the library allocated this copy
    }

    // --- Borrowed array mutated in place (zero-copy) ------------------------
    {
        std::vector<double> a{1.0, 2.0, 3.0, 4.0};
        CVector_borrowed_Float64 vec{{static_cast<int64_t>(a.size())}, a.data()};
        JLWStatus s = jlw_example_scale_inplace(vec, 0.5);
        check(s, "scale_inplace");
        std::printf("scale_inplace ->");
        for (double x : a) std::printf(" %.2f", x);
        std::printf("\n");
    }

    // --- Scalar in / scalar out --------------------------------------------
    {
        std::printf("escape_time(0.5, 0.5) = %lld\n",
                    static_cast<long long>(jlw_example_escape_time(0.5, 0.5, 100).value));
    }

    // --- Owning 2-D array return -------------------------------------------
    {
        const int64_t width = 78, height = 34, maxiter = 250;
        JLWResult_CMatrix_owned_Int32 r =
            jlw_example_mandelbrot(width, height, maxiter);
        check(r.status, "mandelbrot");

        const int64_t rows = r.value.dims[0]; // height
        const int64_t cols = r.value.dims[1]; // width
        const char *ramp = " .:-=+*#%@";
        std::printf("\nMandelbrot %lldx%lld (maxiter %lld):\n", (long long)cols,
                    (long long)rows, (long long)maxiter);
        for (int64_t i = 0; i < rows; ++i) {
            for (int64_t j = 0; j < cols; ++j) {
                // Column-major layout: element (i, j) is at i + j*rows.
                int32_t n = r.value.data[i + j * rows];
                // Interior (never escapes) is solid; exterior fades with n.
                std::putchar(n >= maxiter
                                 ? '@'
                                 : ramp[(n * (int)(std::strlen(ramp) - 1)) / maxiter]);
            }
            std::putchar('\n');
        }
        jlw_free(r.value.data); // release the owned matrix
    }

    return 0;
}
