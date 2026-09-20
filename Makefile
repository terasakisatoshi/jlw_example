# リポジトリ直下のビルド生成物をまとめて扱うための Makefile。
#
#   make all       # 共有ライブラリと各言語デモをビルドして実行 (run_all.sh)
#   make build     # 共有ライブラリ / C ヘッダ / Python パッケージを生成
#   make bundle    # Julia ランタイム同梱版 (out-bundle) を生成
#   make clean     # ビルド生成物を削除

JULIA ?= julia

# .gitignore に載っているビルド生成物。
CLEAN_PATHS := \
	out \
	out-bundle \
	examples/rust/target \
	examples/cpp/demo \
	examples/fortran/demo \
	examples/fortran/*.mod \
	examples/fortran/*.o \
	docs/build

.PHONY: all build bundle clean

all:
	./run_all.sh

build:
	$(JULIA) --project=. build.jl

bundle:
	$(JULIA) --project=. build_bundle.jl

clean:
	rm -rf $(CLEAN_PATHS)
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
