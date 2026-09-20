// Links the demo against the Julia-generated shared library in ../../out.
//
// The library is named `jlw_example.dylib` (macOS) / `jlw_example.so` (Linux),
// i.e. without the usual `lib` prefix, so we pass its path to the linker
// directly and add an rpath so the loader finds it at run time.

use std::env;
use std::path::PathBuf;

fn main() {
    let manifest = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let out = manifest.join("..").join("..").join("out");
    let out = out.canonicalize().expect("run `julia --project=. build.jl` first");
    let lib = if cfg!(target_os = "macos") {
        out.join("jlw_example.dylib")
    } else {
        out.join("jlw_example.so")
    };

    println!("cargo:rustc-link-arg={}", lib.display());
    println!("cargo:rustc-link-arg=-Wl,-rpath,{}", out.display());
    println!("cargo:rerun-if-changed={}", lib.display());
}
