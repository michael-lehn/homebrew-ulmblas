#  Homebrew formula for the tap michael-lehn/homebrew-ulmblas
#  (Formula/ulmblas.rb there):
#
#      brew install michael-lehn/ulmblas/ulmblas
#
#  Installs libulmblas (BLAS: Fortran 77 interface and CBLAS; on Apple
#  Silicon and x86-64 the front that selects the backend for the CPU) and
#  libulmlapack (Reference-LAPACK on top of it), include/ulmblas/cblas.h
#  and the pkg-config files ulmblas.pc and ulmlapack.pc.  The header is in
#  its own directory, beside the cblas.h of other BLAS libraries.
class Ulmblas < Formula
  desc "BLAS and LAPACK with micro kernels selected for the CPU at load time"
  homepage "https://github.com/michael-lehn/ulmBLAS"
  url "https://github.com/michael-lehn/ulmBLAS/archive/refs/tags/v0.4.2.tar.gz"
  sha256 "897ff3e954d973de59e60d9ee1980b02cd8838e7c1fd7ec1b47f7666e66b815b"
  license all_of: ["BSD-3-Clause", "BSD-3-Clause-Open-MPI"]
  revision 1

  depends_on "pkgconf" => :test
  depends_on "gcc" # gfortran for LAPACK, libgfortran at run time

  resource "lapack" do
    url "https://github.com/Reference-LAPACK/lapack/archive/refs/tags/v3.12.1.tar.gz"
    sha256 "2ca6407a001a474d4d4d35f3a61550156050c48016d949f0da0529c0aa052422"
  end

  # macOS: libulmlapack re-exports the LAPACK functions that libulmblas has
  # had since 0.4.2, so programs linked against 0.4.1 load (fixed upstream
  # after 0.4.2, see the CHANGELOG of 0.4.3)
  patch :DATA

  def install
    ENV["LAPACK_TARBALL"] = resource("lapack").cached_download
    ENV["FC"] = formula_opt_bin("gcc")/"gfortran"
    ENV["ULMBLAS_INCLUDEDIR"] = include/"ulmblas"
    # the make of the system, not Homebrew's make wrapper: under it the
    # compiler wrapper removes -O3 and -mcpu=apple-m4 (no SME code in the
    # SME backend, everything at -Os)
    system which("make", ORIGINAL_PATHS), "-j#{ENV.make_jobs}", "install-shared", "PREFIX=#{prefix}"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <stdio.h>
      #include <cblas.h>
      const char *ulmblas_backend(void);
      void dgesv_(const int *n, const int *nrhs, double *A, const int *ldA,
                  int *ipiv, double *B, const int *ldB, int *info);
      int main(void)
      {
          double A[4] = {1, 2, 3, 4}, B[4] = {1, 0, 0, 1}, C[4] = {0};
          cblas_dgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2,
                      1.0, A, 2, B, 2, 0.0, C, 2);
          double M[4] = {4, 1, 1, 3}, x[2] = {1, 2};
          int n = 2, one = 1, ipiv[2], info;
          dgesv_(&n, &one, M, &n, ipiv, x, &n, &info);
          printf("%s %g %g %g %g %d\\n", ulmblas_backend(), C[0], C[1], C[2], C[3], info);
          return !(C[0] == 1 && C[3] == 4 && info == 0);
      }
    C
    flags = shell_output("pkgconf --cflags --libs ulmlapack").split
    system ENV.cc, "test.c", *flags, "-o", "test"
    system "./test"
  end
end

__END__
diff --git a/interfaces/lapack/reference/build.sh b/interfaces/lapack/reference/build.sh
index 12ad7da0..76b33198 100755
--- a/interfaces/lapack/reference/build.sh
+++ b/interfaces/lapack/reference/build.sh
@@ -124,8 +124,17 @@ if [ "$SO" = dll ]; then
     ${DLLTOOL:-dlltool} -d "$BUILD/libulmlapack.def" -D libulmlapack.dll \
         -l "$LIBDIR/ulmlapack.lib" || exit 1
 elif [ "$SO" = dylib ]; then
+    #  macOS binds every symbol to the library it came from at link time
+    #  (two-level namespace): programs linked against a libulmlapack that
+    #  still had the routines of LEFT_OUT look for them here, so they are
+    #  re-exported from libulmblas
+    for r in $LEFT_OUT; do echo "_${r}_"; done > "$BUILD/reexported.txt"
+    REEXPORT=
+    if [ -s "$BUILD/reexported.txt" ]; then
+        REEXPORT="-Wl,-reexported_symbols_list,$BUILD/reexported.txt"
+    fi
     $FC -dynamiclib -install_name @rpath/libulmlapack.dylib \
-        -Wl,-force_load,"$ARCHIVE" -L"$LIBDIR" -lulmblas \
+        -Wl,-force_load,"$ARCHIVE" -L"$LIBDIR" -lulmblas $REEXPORT \
         -Wl,-rpath,@loader_path -o "$OUT" || exit 1
 else
     $FC -shared -Wl,-soname,libulmlapack.so \
