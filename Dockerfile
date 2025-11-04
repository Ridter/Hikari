# Hikari LLVM Obfuscator - Alpine 3.19 Build Container
# This Dockerfile creates an AMD64 build of Hikari LLVM that can be used across platforms

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
    linux-headers

# Set up ccache for faster rebuilds
ENV CCACHE_DIR=/tmp/ccache
ENV CCACHE_MAXSIZE=5G

# Set working directory
WORKDIR /hikari-src

# Copy necessary source directories for LLVM monorepo structure
# The cmake/ directory is required by llvm/CMakeLists.txt
# The third-party/ directory contains benchmark and other dependencies
# The libunwind/ directory contains mach-o headers needed by LLD
COPY cmake/ /hikari-src/cmake/
COPY third-party/ /hikari-src/third-party/
COPY libunwind/ /hikari-src/libunwind/
COPY llvm/ /hikari-src/llvm/
COPY clang/ /hikari-src/clang/
COPY lld/ /hikari-src/lld/

# Configure CMake with Hikari obfuscation enabled
RUN cmake -B/build/build-hikari -G Ninja \
    -DLLVM_ENABLE_RPMALLOC=OFF \
    -DLLVM_TOOL_LLVM_SHLIB_BUILD=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_TOOLS=ON \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLDB_ENABLE_PYTHON=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_ENABLE_ZLIB=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_OBFUSCATION_LINK_INTO_TOOLS=ON \
    -DCMAKE_INSTALL_PREFIX=/opt/hikari \
    -DLLVM_TARGETS_TO_BUILD="X86" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    /hikari-src/llvm

# Build and install
# Use all available cores for parallel compilation
RUN ninja -C /build/build-hikari install

# Create distributable tarball
RUN tar -czf /hikari-llvm-alpine-amd64.tar.gz -C /opt/hikari .

# Stage 2: Minimal runtime image (optional - for direct usage)
FROM alpine:3.19 AS runtime

# Install minimal runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    libgcc

# Copy compiled LLVM/Clang from builder
COPY --from=builder /opt/hikari /opt/hikari

# Add to PATH
ENV PATH="/opt/hikari/bin:${PATH}"

# Verify installation
RUN clang --version && \
    clang++ --version && \
    ld.lld --version

WORKDIR /workspace

# Default command shows available obfuscation options
CMD ["clang", "--help"]

# Stage 3: Distribution stage (for extracting artifacts)
FROM scratch AS dist
COPY --from=builder /hikari-llvm-alpine-amd64.tar.gz /
COPY --from=builder /opt/hikari /opt/hikari
