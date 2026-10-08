set -euo pipefail
cd /work
LLVM_COMMIT=58df0ef89dd64126512e4ee27b4ac3fd8ddf6247   # llvmorg-20.1.2
[ -d llvm-project ] || git clone --depth 1 --branch llvmorg-20.1.2 https://github.com/llvm/llvm-project.git
cd llvm-project
[ "$(git rev-parse HEAD)" = "$LLVM_COMMIT" ] || { echo "llvm-project is not $LLVM_COMMIT (llvmorg-20.1.2)" >&2; exit 1; }
emcmake cmake -Sllvm -Bbuild -GNinja \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DCMAKE_C_FLAGS="-msimd128 -mbulk-memory" -DCMAKE_CXX_FLAGS="-msimd128 -mbulk-memory" \
  -DCMAKE_EXE_LINKER_FLAGS="-s NO_INVOKE_RUN -s EXIT_RUNTIME -s STACK_SIZE=4194304 -s INITIAL_HEAP=134217728 -s ALLOW_MEMORY_GROWTH -s MODULARIZE -s EXPORT_ES6 -s MALLOC=dlmalloc -s EXPORTED_RUNTIME_METHODS=FS,callMain" \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_HOST_TRIPLE=wasm32-unknown-emscripten \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DLLVM_ENABLE_THREADS=OFF -DLLVM_BUILD_TOOLS=OFF -DLLVM_INCLUDE_TESTS=OFF \
  -DCLANG_ENABLE_ARCMT=OFF -DCLANG_ENABLE_STATIC_ANALYZER=OFF
ninja -C build -j10 lld clang
ls -la build/bin
