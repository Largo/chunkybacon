#!/usr/bin/env bash
# Builds the in-browser compiler (html/compile/toolchain/, see
# docs/HANDOVER.md "Program button"): Spinel, clang and lld as WebAssembly,
# plus the runtime, headers and libraries for Windows (mingw-w64, UCRT) and
# Linux (musl, static). Needs docker, git, curl, make, tar, gzip and a C
# compiler; ~10 GB of disk and ~30 minutes (clang + lld for wasm are most of
# it). Every step is skipped when its result exists, so a rerun is cheap.
#
#   tools/compile/build.sh                # -> html/compile/toolchain/
#   WORK=/big/disk tools/compile/build.sh # where the downloads and builds go
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="${WORK:-$ROOT/tools/compile/.work}"
OUT="$ROOT/html/compile/toolchain"
# Everything fetched is pinned and checked, so a changed upstream stops the
# build instead of ending up in the toolchain. To update a pin, change the
# version and the hash together, after looking at what changed.
SPINEL_COMMIT=84f5b5020ef8c519ed4eeca4b7483cd6249d8062   # matz/spinel master of 2026-10-09
LLVM_COMMIT_NOTE="llvmorg-20.1.2 = 58df0ef89dd64126512e4ee27b4ac3fd8ddf6247 (checked in build-llvm.sh)"
ALPINE_IMAGE="alpine@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6"
WASI_SDK_SHA256=b761e3a0721dbae9c09a0059e5fdb2bf917d1b4a8a7b430fb3b5aafb0984b2c4
WASI_SDK_URL="https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-34/wasi-sdk-34.0-x86_64-linux.tar.gz"
MINGW_SHA256=5f9c6ed95b2d4bdb2869a488c5fd5857fbdabcf288a0aa3eb1da43f6a08d8ab4
MINGW_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/20261006/llvm-mingw-20261006-ucrt-ubuntu-22.04-x86_64.tar.xz"
JOBS="${JOBS:-$(nproc)}"

mkdir -p "$WORK" "$OUT/pkg"
cd "$WORK"
step() { printf '\n== %s\n' "$*"; }
die() { echo "build.sh: $*" >&2; exit 1; }
# fetch URL SHA256 DIR TAR-FLAG: download, check the hash, unpack into DIR
fetch() {
  local file="$WORK/download.$$"
  curl -fsSL "$1" -o "$file"
  [ "$(sha256sum "$file" | cut -d' ' -f1)" = "$2" ] || { rm -f "$file"; die "$1 does not match its pinned sha256 $2"; }
  mkdir -p "$3" && tar "$4" -f "$file" -C "$3" --strip-components=1 && rm -f "$file"
}
# check_files SHA256SUMS-FILE-CONTENT: run inside the directory the names are relative to
check_files() { printf '%s\n' "$1" | sha256sum -c --quiet - || die "files differ from their pinned sha256 in $PWD"; }

step "tools: wasi-sdk, llvm-mingw"
[ -d wasi-sdk ] || fetch "$WASI_SDK_URL" "$WASI_SDK_SHA256" wasi-sdk x"z"
[ -d llvm-mingw ] || fetch "$MINGW_URL" "$MINGW_SHA256" llvm-mingw x"J"
W="$WORK/wasi-sdk"; M="$WORK/llvm-mingw"; export PATH="$M/bin:$PATH"

step "Spinel $SPINEL_COMMIT"
[ -d spinel ] || { git clone -q https://github.com/matz/spinel spinel; }
git -C spinel checkout -q "$SPINEL_COMMIT"
[ "$(git -C spinel rev-parse HEAD)" = "$SPINEL_COMMIT" ] || die "spinel is not at $SPINEL_COMMIT"
make -C spinel deps >/dev/null
fresh() { rm -rf "$1" && cp -r spinel "$1" && make -C "$1" clean >/dev/null 2>&1 || true; }

step "Spinel as WebAssembly (the translator: Ruby -> C)"
if [ ! -f sp-wasi/bin/spinel ]; then
  fresh sp-wasi
  ( cd "$HERE/shim" && "$W/bin/clang" --sysroot="$W/share/wasi-sysroot" --target=wasm32-wasip1 -c stubs.c -o "$WORK/stubs.o" -I. )
  CCW="$W/bin/clang --sysroot=$W/share/wasi-sysroot --target=wasm32-wasip1 -mllvm -wasm-enable-sjlj -mllvm -wasm-use-legacy-eh=false -D_WASI_EMULATED_MMAN -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_PROCESS_CLOCKS -D_WASI_EMULATED_GETPID -I$HERE/shim -include $HERE/shim/wasi_shim.h"
  make -C sp-wasi deps >/dev/null
  make -C sp-wasi -j"$JOBS" CC="$CCW" \
    LDFLAGS="$WORK/stubs.o -lsetjmp -lwasi-emulated-mman -lwasi-emulated-signal -lwasi-emulated-process-clocks -lwasi-emulated-getpid -Wl,-z,stack-size=67108864" bin/spinel
fi

step "Spinel's runtime for Windows and Linux"
if [ ! -f sp-win/lib/libspinel_rt.a ]; then
  fresh sp-win
  make -C sp-win -j"$JOBS" CC=x86_64-w64-mingw32-clang lib/libspinel_rt.a >/dev/null
fi
if [ ! -d musl/usr/include ]; then   # musl's headers and libc.a, from Alpine
  mkdir -p musl
  docker run --rm -v "$WORK/musl:/out" "$ALPINE_IMAGE" sh -c 'apk add -q musl-dev gcc linux-headers >/dev/null 2>&1
    mkdir -p /out/usr/lib /out/usr/include; cp -r /usr/include/. /out/usr/include/
    cp /usr/lib/libc.a /usr/lib/libm.a /usr/lib/crt1.o /usr/lib/crti.o /usr/lib/crtn.o /out/usr/lib/
    cp /usr/lib/gcc/x86_64-alpine-linux-musl/*/libgcc.a /usr/lib/gcc/x86_64-alpine-linux-musl/*/libgcc_eh.a /out/usr/lib/
    chown -R '"$(id -u):$(id -g)"' /out'
fi
# Alpine's packages are not pinned by the image: what they delivered is
( cd musl/usr/lib && check_files "ff0d5e7ac47afd296bb8bad4a67d4b0efbc763298a9fe6a4b1ee3e9d0fc6ec68  libc.a
f0a17a43c74d2fe5474fa2fd29c8f14799e777d7d75a2cc4d11c20a6e7b161c5  libm.a
a1cbdbe2d03f995120cbbea2138eabef26b82c3f090c5e592296b1ec6394c935  crt1.o
a0af2446e5bce05119163883c5d522c3c44e3a9d1aa5014f468c1feb8dc2cb54  crti.o
596ea32e1d1782df9f25f8326013832ca5fe391e26f84382c6731c2a37263260  crtn.o
aeae756b465a790521bc47a999d0c935c3efad7df06e1b89d334f52d371918e2  libgcc.a
65f99a00a2dfa938816b0d60aecbb3a27c7ade6673b87e2c7fdb357ac8371d02  libgcc_eh.a" )
[ "$(cd musl/usr/include && find . -type f | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -d' ' -f1)" = e6a443cc73f6376888206c4fc6144f1665c15fa5d38526e5e4029f1297997b26 ] || die "musl's headers differ from the pinned ones"
if [ ! -f sp-lin/lib/libspinel_rt.a ]; then
  fresh sp-lin
  make -C sp-lin -j"$JOBS" CC="clang --target=x86_64-linux-musl --sysroot=$WORK/musl -isystem $WORK/musl/usr/include" lib/libspinel_rt.a >/dev/null
fi

step "clang and lld for WebAssembly, with the x86 backend (LLVM 20, long)"
if [ ! -f llvm-work/llvm-project/build/bin/clang.wasm ]; then
  mkdir -p llvm-work
  docker build -q -t chunky-llvm-wasm "$HERE" >/dev/null
  docker run --rm -v "$WORK/llvm-work:/work" -v "$HERE/build-llvm.sh:/build-llvm.sh" chunky-llvm-wasm bash /build-llvm.sh
fi
LB="$WORK/llvm-work/llvm-project/build"

step "packages"
rm -rf stage && mkdir -p stage/res stage/win/{inc,lib,spinel/regexp} stage/linux/{inc,lib,spinel/regexp} stage/sp/{bin,lib}
cp -r "$LB/lib/clang/20/include" stage/res/include
# Spinel's own files for the translator: the Ruby part of its core library and a place for the paths it checks
cp -r spinel/builtins stage/sp/builtins; : > stage/sp/bin/spinel; : > stage/sp/lib/libspinel_rt.a
# Windows: mingw's headers without what Spinel's C never includes (COM IDL, DirectX, drivers, C++), the libraries the link line names
MI="$M/x86_64-w64-mingw32"
cp -rL "$MI/include/." stage/win/inc/
rm -rf stage/win/inc/c++ stage/win/inc/ddk stage/win/inc/GL stage/win/inc/*.idl stage/win/inc/mshtml*
find stage/win/inc -type f -size +300k -delete
for f in crt2.o crtbegin.o crtend.o libws2_32.a libbcrypt.a libwinpthread.a libm.a libmingw32.a libmoldname.a libmingwex.a libmsvcrt.a libadvapi32.a libshell32.a libuser32.a libkernel32.a libunwind.a; do
  cp -L "$MI/lib/$f" stage/win/lib/
done
cp "$M"/lib/clang/*/lib/windows/libclang_rt.builtins-x86_64.a stage/win/lib/
cp -r sp-win/lib/win32 stage/win/spinel/win32; find stage/win/spinel/win32 \( -name '*.c' -o -name '*.a' \) -delete
cp sp-win/lib/*.h stage/win/spinel/; cp sp-win/lib/regexp/*.h stage/win/spinel/regexp/; cp sp-win/lib/libspinel_rt.a stage/win/spinel/
# Linux: musl without debug sections (the wasm lld has no zlib)
cp -rL musl/usr/include/. stage/linux/inc/; cp musl/usr/lib/*.a musl/usr/lib/*.o stage/linux/lib/
for f in stage/linux/lib/*; do llvm-strip --strip-debug "$f"; done
cp sp-lin/lib/*.h stage/linux/spinel/; cp sp-lin/lib/regexp/*.h stage/linux/spinel/regexp/; cp sp-lin/lib/libspinel_rt.a stage/linux/spinel/
for p in win linux res; do tar -C stage/$p -cf - . | gzip -9n > "$OUT/pkg/$p.tar.gz"; done
tar -C stage/sp -cf - . | gzip -9n > "$OUT/pkg/spinel.tar.gz"

step "the wasm modules (gzipped beside the file: nginx's gzip_static serves them)"
cp sp-wasi/bin/spinel "$OUT/spinel.wasm"
cp "$LB/bin/clang.js-20" "$OUT/clang.js"; cp "$LB/bin/clang.wasm" "$OUT/clang.wasm"
cp "$LB/bin/lld.js" "$OUT/lld.js"; cp "$LB/bin/lld.wasm" "$OUT/lld.wasm"
for f in spinel.wasm clang.wasm lld.wasm clang.js lld.js; do gzip -9nkf "$OUT/$f"; done
# what was built, with the hash of every file, for whoever audits a deployment
{
  printf '{"spinel":"%s","llvm":"20.1.2","emscripten":"6.0.11","wasi-sdk":"34","llvm-mingw":"20261006","files":{' "$SPINEL_COMMIT"
  ( cd "$OUT" && sha256sum spinel.wasm clang.js clang.wasm lld.js lld.wasm pkg/*.tar.gz ) | awk '{printf "%s\"%s\":\"%s\"", (NR>1?",":""), $2, $1}'
  printf '}}\n'
} > "$OUT/ready.json"
du -sh "$OUT"; echo "done: reload the page, cells get a 📦 button"
