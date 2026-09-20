# jlw_example

[JuliaLibWrapping.jl](https://github.com/JuliaInterop/JuliaLibWrapping.jl) (JLW) で Julia のコードを共有ライブラリに変換し、Python、C++、Fortran、Rust から呼び出す例である。
題材は Mandelbrot 集合の描画と、境界をまたぐ文字列・スカラー・配列の受け渡しである。

## クイックデモ

`git clone` から一通りの機能（Python、C++、Fortran、Rust、Julia 非依存 bundle）を実行するまでのコマンド。
ローカル経路と Docker 経路はどちらか一方を実行すればよい。
両方を続けて試す場合は、2 つ目の clone 先を変える（Docker 経路の例を参照）。

### ローカルで実行する

前提として Julia 1.13 以降、C++ コンパイラ、gfortran、cargo、Python 3 と NumPy が要る（[必要環境](#必要環境)）。

```sh
git clone https://github.com/terasakisatoshi/jlw_example.git
cd jlw_example
./run_all.sh
```

`run_all.sh` が共有ライブラリと Python パッケージを生成し、Python、C++、Fortran、Rust のデモを順に実行する。
最後に `All demos ran successfully.` と出れば成功である。

続けて Julia 非依存の配布用パッケージを試す。

```sh
julia --project=. build_bundle.jl
python3 -m venv /tmp/jlw_bundle-venv
/tmp/jlw_bundle-venv/bin/pip install ./out-bundle
/tmp/jlw_bundle-venv/bin/python -c 'from jlw_example_py import hello; print(hello("world"))'
```

### Docker で実行する

Julia や各言語のツールチェーンをローカルに入れずに試す場合は Docker を使う（[Docker](#docker)）。
Docker と `make` が要る。

```sh
git clone https://github.com/terasakisatoshi/jlw_example.git jlw_example-docker
cd jlw_example-docker
make -C docker run-all
```

ビルド用イメージを生成したあと、Python、C++、Fortran、Rust、bundle の各イメージをビルドして実行する。

## 何を確かめられるか

この例は JLW の境界仕様を一通り触れるようにしてある。

- Julia の `String` を Python の `str`、C の `CString_owned` として受け渡す。
- `Int` と `Float64` のスカラーをそのまま受け渡す。
- `Matrix{Int32}` を所有権付き配列として返し、呼び出し側が Julia 列優先のデータを読む。
- `Vector{Float64}` を借用配列として渡し、Julia 側の変更を呼び出し側で観測する。

Python 向けのラッパーは JLW が生成する。
C++、Fortran、Rust 向けのバインディングは生成されないため、生成された C ヘッダ `out/jlw_example.h` を各言語から直接使う。

## 必要環境

- Julia 1.13 以降
- JLWInterop 0.2、JuliaLibWrapping 0.2、JuliaC 0.3（`Pkg.instantiate` が導入する）
- C++ コンパイラ、gfortran、cargo、Python 3 と NumPy

## ビルドと実行

すべてまとめて実行するなら次で足りる。

```sh
./run_all.sh
```

手動で進める場合は 3 段階に分かれる。

```sh
julia --project=build-env -e 'using Pkg; Pkg.instantiate()'   # ビルド用ツール
julia --project=. -e 'using Pkg; Pkg.instantiate()'           # ライブラリの実行依存
julia --project=. build.jl                                    # 共有ライブラリとラッパー生成
```

`build.jl` は `build_library` を `bundle = false` で呼ぶ。
`bundle = false` のとき生成ライブラリはビルドマシンの `libjulia` を参照するので、実行環境に Julia がある前提になる。
配布用に単体で動くパッケージを作る場合は `bundle = true` と `privatize` を使う（[Bundling for distribution](https://juliainterop.github.io/JuliaLibWrapping.jl/stable/building/#Bundling-for-distribution)）。

ビルド後の `out/` は次の構成になる。

```
out/
├── jlw_example.dylib        # 共有ライブラリ (Linux では .so)
├── jlw_example.h            # C ヘッダ
├── jlw_example.abi.json     # juliac が出力する ABI 情報
├── jlw_example.jlw.json     # @api 宣言のメタデータ
├── pyproject.toml
└── jlw_example_py/          # Python パッケージ
    ├── __init__.py
    ├── _facade.py           # 編集可能な薄いラッパー
    └── _lowlevel.py         # ctypes の機械的バインディング
```

`build.jl` は生成直後に共有ライブラリを `out/jlw_example_py/` へ複製する。
生成された Python ローダーはパッケージと同じディレクトリのライブラリを探すためである。

### Julia 非依存の配布用パッケージ

Julia をインストールしていない環境へ配る場合は `build_bundle.jl` を使う。

```sh
julia --project=. build_bundle.jl
```

これは `standard_build` を既定の `bundle = true` で呼び、`out-bundle/` に生成する。
Julia ランタイム一式が `out-bundle/jlw_example_py/bundle/lib/` に同梱され、`libjulia` は私有化される。
私有化（`privatize`）は共有ライブラリの install name を `@loader_path` 基準へ書き換えるので、環境変数を設定しなくても実行時に同梱ランタイムが見つかる。
生成された Python ローダーも、パッケージ直下より先に `bundle/lib` を探す。
サイズは数十 MB 増えるが、`pip install` だけで動く。

```sh
python3 -m venv /tmp/jlw_bundle-venv
/tmp/jlw_bundle-venv/bin/pip install ./out-bundle
/tmp/jlw_bundle-venv/bin/python -c 'from jlw_example_py import hello; print(hello("world"))'
```

この最後のコマンドは `Hello, world` を出力する（Julia が `PATH` に無くてもよい）。

`out-bundle/` の主な構成は次のとおり。ランタイムは `jlw_example_py/bundle/lib/` に入る。

```
out-bundle/
├── jlw_example_py/
│   ├── _facade.py
│   ├── _lowlevel.py
│   └── bundle/
│       └── lib/              # 私有化された libjulia と依存ライブラリ
│           ├── <hash>_libjulia*.dylib
│           ├── jlw_example.dylib
│           └── julia/
├── jlw_example.h
├── jlw_example.abi.json
├── jlw_example.jlw.json
└── pyproject.toml
```

`pyproject.toml` は `numpy>=1.20` に依存するため、Julia の無い環境でも PyPI へのアクセスは必要である。
完全にオフラインで配る場合は事前に wheel を用意する。

C++、Fortran、Rust のデモは `out/` のライブラリを前提にしている。

## 公開 API

`src/jlw_example.jl` の `@api` 宣言が外部に見える境界を決める。
`@export_release_entrypoints` は所有権付きの戻り値を解放する `jlw_free` を出力する。文字列と配列を返す API には必須である。

| Julia の関数 | 引数 | 戻り値 | 生成される C 関数 |
| --- | --- | --- | --- |
| `hello(who)` | `String` | `String` | `jlw_example_hello` |
| `escape_time(cx, cy; maxiter)` | `Float64`, `Float64`, `Int` | `Int` | `jlw_example_escape_time` |
| `mandelbrot(width, height; maxiter)` | `Int`, `Int`, `Int` | `Matrix{Int32}` | `jlw_example_mandelbrot` |
| `scale_inplace(a; factor)` | `Vector{Float64}`, `Float64` | `Nothing` | `jlw_example_scale_inplace` |

C の関数名は宣言したモジュール名で修飾される。
各言語のラッパーはこの修飾名をそのまま使う。

## 言語ごとの要点

### Python

生成された `_facade.py` が NumPy 配列と `str` を扱う。
`mandelbrot` は `(height, width)` の `int32` 配列を返し、所有権付きカーリを `finally` で解放する。

```sh
python3 -m venv /tmp/jlw_example-venv
/tmp/jlw_example-venv/bin/pip install numpy
PYTHONPATH=out /tmp/jlw_example-venv/bin/python examples/python/demo.py
```

`demo.py` は先頭で `Hello, Python`、続けて `scale_inplace -> [0.5 1.  1.5 2. ]` と `escape_time(0.5, 0.5) = 5` を出力し、最後に Mandelbrot を文字で描く。

`out/` には `pyproject.toml` もあるので、パッケージとして導入してもよい（`numpy` は依存として自動導入される）。

```sh
/tmp/jlw_example-venv/bin/pip install ./out
/tmp/jlw_example-venv/bin/python examples/python/demo.py
```

### C++

生成ヘッダは C リンケージで書かれているため、C++ からは `extern "C"` で囲んで読み込む。
これがないとシンボル名がマングリングされてリンクに失敗する。
文字列・行列を返す API の戻り値は所有権付きなので、`JLWResult_*.value` を使い終えたら `jlw_free(value.data)` を呼ぶ（`examples/cpp/demo.cpp` 参照）。

```sh
c++ -std=c++17 -Iout examples/cpp/demo.cpp out/jlw_example.dylib \
    -Wl,-rpath,$PWD/out -o examples/cpp/demo && ./examples/cpp/demo
```

`demo` は `Hello, C++`、`scale_inplace -> 0.50 1.00 1.50 2.00`、`escape_time(0.5, 0.5) = 5` を出力し、最後に Mandelbrot を文字で描く。

### Fortran

`iso_c_binding` で構造体のレイアウトを写す。
`mandelbrot` が返す配列は Julia と同じ列優先なので、`c_f_pointer` で `(height, width)` の配列としてそのまま読める。
文字列と行列の解放は `jlw_free` を呼ぶ。

```sh
gfortran examples/fortran/demo.f90 out/jlw_example.dylib \
    -Wl,-rpath,$PWD/out -o examples/fortran/demo && ./examples/fortran/demo
```

`gfortran` は構造体を値で返す C 関数を扱える必要がある（GCC 8 以降で確認）。
`demo` は `Hello, C++`、`scale_inplace -> 0.50  1.00  1.50  2.00`、`escape_time(0.5, 0.5) = 5` を出力する。

### Rust

ABI 構造体を `#[repr(C)]` で定義し、`build.rs` からライブラリのパスと `rpath` をリンカに渡す。
共有ライブラリ名に `lib` 接頭辞が付かないため、`-l` ではなくパスを直接渡している。

```sh
cargo run --manifest-path examples/rust/Cargo.toml
```

`examples/rust/Cargo.toml` は edition 2021 を使う。
`cargo run` は `Hello, Rust`、`scale_inplace -> [0.5, 1.0, 1.5, 2.0]`、`escape_time(0.5, 0.5) = 5` を出力する。

## 境界の規約

配列は**列優先**である。
要素 `(i, j)` は `data[i + j*rows]` で読む。
戻り値の行列は `dims = (rows, cols) = (height, width)` の順で次元を持つ。
たとえば `mandelbrot(3, 2)` は `dims = (2, 3)`、長さ 6 の `data` を返し、0 始まりの `data[i + j*rows]` が 1 始まりの要素 `(i+1, j+1)` に対応する。
Python の NumPy は行優先が既定なので、N 次元配列を渡すときは `np.asfortranarray` が要る（この例では 1 次元配列しか渡していない）。

引数の配列は**借用**で、呼び出し側がメモリを所有する。
Julia 側の変更は呼び出し側から見える。
戻り値の配列と文字列は**所有権付き**で、ライブラリが確保したコピーを呼び出し側が `jlw_free` で解放する。

エラーは `JLWStatus.code` で伝わる。
`code == 0` が成功で、非ゼロのとき `message` に例外メッセージが入る。
Python では `JLWError` として送出される。

## Docker

言語ごとの実行用イメージと、共有ライブラリを生成するビルド用イメージを `docker/` に用意してある。
ビルド用が Julia をコンパイルする唯一のイメージで、実行用はその上にツールチェーンを足してデモを走らせるだけである。
ビルド順（ビルド用 → 各言語）は `Makefile` が面倒を見る。

```sh
make -C docker all        # ビルド用と全言語のイメージを作る
make -C docker run-all    # ビルドして各イメージを実行する
```

手動で進める場合は次のとおり。

```sh
docker build -f docker/Dockerfile.build -t jlw_example-build .
docker build -f docker/Dockerfile.python -t jlw_example-python .
docker run --rm jlw_example-python
```

実行用は `Dockerfile.python`、`Dockerfile.cpp`、`Dockerfile.fortran`、`Dockerfile.rust`、`Dockerfile.bundle` の 5 つ。
`Dockerfile.bundle` だけは Julia を入れない `python` イメージへ `out-bundle/` を導入し、Julia 無しで動くことを確かめる。
詳細と `BUILD_IMAGE` / `RUST_IMAGE` の上書きは `docker/README.md` を参照。
Docker 内は Linux なので共有ライブラリは `jlw_example.so` になる。

## ファイル構成

```
jlw_example/
├── Project.toml            # 実行依存 (JLWInterop)
├── build-env/Project.toml  # ビルド用ツール (JuliaC, JuliaLibWrapping)
├── build.jl                # build_library の呼び出し
├── build_bundle.jl         # Julia 非依存の配布用 (bundle = true)
├── run_all.sh              # 全言語のビルドと実行
├── src/jlw_example.jl      # @api 宣言と本体
├── docker/                 # ビルド用/言語別の Dockerfile
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
