# The image that builds clang and lld for WebAssembly (build-llvm.sh).
# Everything it downloads is pinned: the base image by digest, emsdk by
# commit, Emscripten by version (emsdk brings its own node and python, so
# there is no nvm here). The apt packages are Ubuntu's of the day.
FROM ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55

RUN apt update && apt install -y \
    build-essential \
    cmake \
    git \
    python3 \
    curl \
    ninja-build && \
    rm -rf /var/lib/apt/lists/*

ENV EMSDK_DIR=/root/emsdk
ENV EMSDK_COMMIT=b44154299bdefe75ba287874bb63fc9806243771
ENV EMSCRIPTEN_VERSION=6.0.11
RUN git clone -q https://github.com/emscripten-core/emsdk.git ${EMSDK_DIR} && \
    git -C ${EMSDK_DIR} checkout -q ${EMSDK_COMMIT} && \
    ${EMSDK_DIR}/emsdk install ${EMSCRIPTEN_VERSION} && ${EMSDK_DIR}/emsdk activate ${EMSCRIPTEN_VERSION}

ENTRYPOINT ["bash", "-c", "source $EMSDK_DIR/emsdk_env.sh && exec \"$@\"", "--"]
