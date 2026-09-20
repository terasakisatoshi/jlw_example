//! Call the Julia-generated shared library from Rust.
//!
//! Run (from the repository root, after `julia --project=. build.jl`):
//!   cargo run --manifest-path examples/rust/Cargo.toml

use std::ffi::c_void;

// --- ABI structs, mirroring out/jlw_example.h (all repr(C)) ----------------

#[repr(C)]
struct JLWStatus {
    code: i32,
    message: [u8; 256],
}

#[repr(C)]
struct JLWResultInt64 {
    status: JLWStatus,
    value: i64,
}

#[repr(C)]
struct CVectorBorrowedFloat64 {
    dims: [i64; 1],
    data: *mut f64,
}

#[repr(C)]
struct CStringBorrowed {
    length: i64,
    data: *mut u8,
}

#[repr(C)]
struct CStringOwned {
    length: i64,
    data: *mut u8,
}

#[repr(C)]
struct JLWResultCStringOwned {
    status: JLWStatus,
    value: CStringOwned,
}

#[repr(C)]
struct CMatrixOwnedInt32 {
    dims: [i64; 2],
    data: *mut i32,
}

#[repr(C)]
struct JLWResultCMatrixOwnedInt32 {
    status: JLWStatus,
    value: CMatrixOwnedInt32,
}

extern "C" {
    fn jlw_free(p: *mut c_void);
    fn jlw_example_hello(who: CStringBorrowed) -> JLWResultCStringOwned;
    fn jlw_example_escape_time(cx: f64, cy: f64, maxiter: i64) -> JLWResultInt64;
    fn jlw_example_scale_inplace(a: CVectorBorrowedFloat64, factor: f64) -> JLWStatus;
    fn jlw_example_mandelbrot(width: i64, height: i64, maxiter: i64)
        -> JLWResultCMatrixOwnedInt32;
}

fn check(status: &JLWStatus, what: &str) {
    if status.code != 0 {
        let end = status
            .message
            .iter()
            .position(|&b| b == 0)
            .unwrap_or(status.message.len());
        let msg = String::from_utf8_lossy(&status.message[..end]);
        panic!("{what} failed [{}]: {msg}", status.code);
    }
}

fn main() {
    // --- String crossing the boundary (owning return) ----------------------
    unsafe {
        let name = b"Rust";
        let arg = CStringBorrowed {
            length: name.len() as i64,
            data: name.as_ptr() as *mut u8,
        };
        let r = jlw_example_hello(arg);
        check(&r.status, "hello");
        let bytes = std::slice::from_raw_parts(r.value.data, r.value.length as usize);
        println!("{}", String::from_utf8_lossy(bytes));
        jlw_free(r.value.data as *mut c_void);
    }

    // --- Borrowed array mutated in place -----------------------------------
    unsafe {
        let mut a = vec![1.0_f64, 2.0, 3.0, 4.0];
        let vec = CVectorBorrowedFloat64 {
            dims: [a.len() as i64],
            data: a.as_mut_ptr(),
        };
        let s = jlw_example_scale_inplace(vec, 0.5);
        check(&s, "scale_inplace");
        println!("scale_inplace -> {a:?}");
    }

    // --- Scalar in / scalar out --------------------------------------------
    unsafe {
        let r = jlw_example_escape_time(0.5, 0.5, 100);
        check(&r.status, "escape_time");
        println!("escape_time(0.5, 0.5) = {}", r.value);
    }

    // --- Owning 2-D array return -------------------------------------------
    unsafe {
        let (width, height, maxiter) = (78_i64, 34_i64, 250_i64);
        let r = jlw_example_mandelbrot(width, height, maxiter);
        check(&r.status, "mandelbrot");

        let rows = r.value.dims[0] as usize;
        let cols = r.value.dims[1] as usize;
        let data = std::slice::from_raw_parts(r.value.data, rows * cols);
        let ramp: Vec<char> = " .:-=+*#%@".chars().collect();

        println!("\nMandelbrot {cols}x{rows} (maxiter {maxiter}):");
        for i in 0..rows {
            let mut line = String::with_capacity(cols);
            for j in 0..cols {
                let n = data[i + j * rows]; // column-major
                if n as i64 >= maxiter {
                    line.push('@');
                } else {
                    let idx = (n as usize * (ramp.len() - 1)) / maxiter as usize;
                    line.push(ramp[idx]);
                }
            }
            println!("{line}");
        }
        jlw_free(r.value.data as *mut c_void);
    }
}
