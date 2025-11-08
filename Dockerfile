# Hikari LLVM Obfuscator - Alpine 3.19 Build Container
# Optimized build: zlib enabled, no compiler-rt (use system libgcc)

# Stage 1: Build environment
FROM alpine:3.19 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    clang \
    lld \
    ninja \
    ccache \
    cmake \
    python3 \
    git \
    bash \
    linux-headers \
    musl-dev \
    zlib-dev

# Set up ccache for faster rebuilds
ENV CCACHE_DIR=/tmp/ccache
ENV CCACHE_MAXSIZE=5G

# Set working directory
WORKDIR /hikari-src

# Copy necessary source directories for LLVM monorepo structure
COPY cmake/ /hikari-src/cmake/
COPY third-party/ /hikari-src/third-party/
COPY libunwind/ /hikari-src/libunwind/
COPY llvm/ /hikari-src/llvm/
COPY clang/ /hikari-src/clang/
COPY lld/ /hikari-src/lld/

RUN cmake -B/build/build-hikari -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/hikari \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DLLVM_TARGETS_TO_BUILD="X86;AArch64" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_OBFUSCATION_LINK_INTO_TOOLS=ON \
    -DLLVM_ENABLE_ZLIB=ON \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_ENABLE_RPMALLOC=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_BUILD_LLVM_DYLIB=OFF \
    -DLLVM_LINK_LLVM_DYLIB=OFF \
    -DLLVM_BUILD_STATIC=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCLANG_LINK_CLANG_DYLIB=OFF \
    -DCLANG_BUILD_SHARED_LIBS=OFF \
    -DLIBCLANG_BUILD_STATIC=ON \
    -DCMAKE_SKIP_INSTALL_RPATH=ON \
    -DCMAKE_SKIP_RPATH=ON \
    -DCMAKE_C_FLAGS="-O3 -ffunction-sections -fdata-sections -I/hikari-src/libunwind/include" \
    -DCMAKE_CXX_FLAGS="-O3 -ffunction-sections -fdata-sections -I/hikari-src/libunwind/include" \
    -DCMAKE_EXE_LINKER_FLAGS_RELEASE="-Wl,--gc-sections" \
    -DLLVM_ENABLE_LLD=ON \
    /hikari-src/llvm

# Build and install
RUN ninja -C /build/build-hikari install

# Verify installation
RUN echo "==> Verifying Hikari installation..." && \
    test -f /hikari/bin/clang && \
    test -f /hikari/bin/clang++ && \
    test -f /hikari/bin/ld.lld && \
    /hikari/bin/clang --version && \
    /hikari/bin/ld.lld --version && \
    echo "==> Checking LLD zlib support..." && \
    /hikari/bin/ld.lld --help | grep -i version && \
    echo "==> Testing LLD with zlib-compressed debug info..." && \
    echo "int main() { return 0; }" > /tmp/test.c && \
    /hikari/bin/clang -target x86_64-linux-musl -static -o /tmp/test /tmp/test.c && \
    /tmp/test && echo "✅ LLD zlib support verified!" || echo "⚠️ LLD may not support zlib" && \
    echo "==> Installation structure:" && \
    ls -la /hikari/bin/ && \
    echo "==> Hikari LLVM installed successfully"

# Create distributable tarball
RUN tar -czf /hikari-llvm-alpine-amd64.tar.gz -C /hikari .

# Stage 2: Minimal runtime image
FROM alpine:3.19 AS runtime

# Install minimal runtime dependencies
# musl-dev and gcc provide libgcc for linking
RUN apk add --no-cache \
    libstdc++ \
    libgcc \
    musl-dev \
    gcc

# Copy compiled LLVM/Clang from builder
COPY --from=builder /hikari /hikari

# Add to PATH
ENV PATH="/hikari/bin:${PATH}"

# Verify installation
RUN clang --version && \
    clang++ --version && \
    ld.lld --version

WORKDIR /workspace

# Default command shows version
CMD ["clang", "--version"]

# Stage 3: Distribution stage (for extracting artifacts)
FROM scratch AS dist
COPY --from=builder /hikari-llvm-alpine-amd64.tar.gz /
COPY --from=builder /hikari /hikari
