# Homebrew tap for ulmBLAS

```sh
brew install michael-lehn/ulmblas/ulmblas
```

Installs libulmblas (BLAS: Fortran 77 interface and CBLAS; the backend for
the CPU is selected at load time: SME2 or NEON on Apple Silicon, AVX-512,
AVX2 or SSE3 on x86-64) and libulmlapack (Reference-LAPACK on top of it),
`include/ulmblas/cblas.h`, and the pkg-config files `ulmblas` and
`ulmlapack`.

```sh
cc prog.c $(pkg-config --cflags --libs ulmlapack)
```

NumPy on ulmBLAS: `interfaces/python/numpy.sh $(brew --prefix ulmblas) VENV`
in the ulmBLAS sources.

ulmBLAS: https://github.com/michael-lehn/ulmBLAS
