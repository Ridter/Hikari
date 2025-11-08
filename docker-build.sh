#!/usr/bin/env bash

# Hikari LLVM Alpine Docker Build Script
# This script simplifies building the Hikari LLVM obfuscator in a Docker container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="${DOCKER_IMAGE_NAME:-hikari-llvm}"
IMAGE_TAG="${DOCKER_IMAGE_TAG:-alpine-3.19}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
OUTPUT_DIR="${OUTPUT_DIR:-./hikari-install}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

# Detect CPU cores for build parallelism
if [[ "$OSTYPE" == "darwin"* ]]; then
    CORES=$(sysctl -n hw.ncpu)
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CORES=$(nproc)
else
    CORES=4
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Hikari LLVM Alpine Builder${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Image:${NC} ${FULL_IMAGE_NAME}"
echo -e "${GREEN}Platform:${NC} ${PLATFORM}"
echo -e "${GREEN}CPU Cores:${NC} ${CORES}"
echo -e "${GREEN}Output Dir:${NC} ${OUTPUT_DIR}"
echo ""

# Function to print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build Hikari LLVM obfuscator in Alpine 3.19 Docker container

OPTIONS:
    -h, --help              Show this help message
    -b, --build-only        Only build the Docker image, don't extract
    -e, --extract-only      Only extract from existing image
    -c, --clean             Clean build (no cache)
    -o, --output DIR        Output directory (default: ./hikari-install)
    -t, --tag TAG           Docker image tag (default: alpine-3.19)
    -p, --platform PLATFORM Docker platform (default: linux/amd64)

ENVIRONMENT VARIABLES:
    DOCKER_IMAGE_NAME       Docker image name (default: hikari-llvm)
    DOCKER_IMAGE_TAG        Docker image tag (default: alpine-3.19)
    DOCKER_PLATFORM         Docker platform (default: linux/amd64)
    OUTPUT_DIR              Output directory for extracted files

EXAMPLES:
    # Full build and extract
    $0

    # Clean build without cache
    $0 --clean

    # Only build image
    $0 --build-only

    # Extract to custom directory
    $0 --output /tmp/hikari
EOF
}

# Parse arguments
BUILD_ONLY=false
EXTRACT_ONLY=false
CLEAN_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -b|--build-only)
            BUILD_ONLY=true
            shift
            ;;
        -e|--extract-only)
            EXTRACT_ONLY=true
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
            shift 2
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Build Docker image
build_image() {
    echo -e "${YELLOW}[1/2] Building Docker image...${NC}"

    BUILD_ARGS=(
        "buildx"
        "build"
        "--platform" "${PLATFORM}"
        "-t" "${FULL_IMAGE_NAME}"
        "-f" "Dockerfile"
        "--target" "runtime"
        "--load"
    )

    if [ "$CLEAN_BUILD" = true ]; then
        echo -e "${YELLOW}Performing clean build (no cache)...${NC}"
        BUILD_ARGS+=("--no-cache")
    fi

    BUILD_ARGS+=(".")

    if ! docker "${BUILD_ARGS[@]}"; then
        echo -e "${RED}Error: Docker build failed${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Docker image built successfully${NC}"
    echo ""
}

# Extract compiled binaries
extract_binaries() {
    echo -e "${YELLOW}[2/2] Extracting compiled binaries...${NC}"

    # Remove old output directory if exists
    if [ -d "$OUTPUT_DIR" ]; then
        echo -e "${YELLOW}Removing existing output directory...${NC}"
        rm -rf "$OUTPUT_DIR"
    fi

    # Create temporary container
    echo -e "${BLUE}Creating temporary container...${NC}"
    CONTAINER_ID=$(docker create "${FULL_IMAGE_NAME}")

    if [ -z "$CONTAINER_ID" ]; then
        echo -e "${RED}Error: Failed to create container${NC}"
        exit 1
    fi

    # Copy files from container
    echo -e "${BLUE}Copying files from container...${NC}"
    if ! docker cp "${CONTAINER_ID}:/hikari" "$OUTPUT_DIR"; then
        echo -e "${RED}Error: Failed to copy files from container${NC}"
        docker rm "${CONTAINER_ID}" >/dev/null 2>&1
        exit 1
    fi

    # Clean up container
    echo -e "${BLUE}Cleaning up temporary container...${NC}"
    docker rm "${CONTAINER_ID}" >/dev/null 2>&1

    echo -e "${GREEN}✓ Binaries extracted to: ${OUTPUT_DIR}${NC}"
    echo ""

    # Show summary
    echo -e "${GREEN}Installed binaries:${NC}"
    if [ -d "$OUTPUT_DIR/bin" ]; then
        ls -lh "$OUTPUT_DIR/bin/" | grep -E "clang|lld" | awk '{print "  - " $9 " (" $5 ")"}'
    fi
    echo ""
}

# Create tarball for distribution
create_tarball() {
    echo -e "${YELLOW}Creating distribution tarball...${NC}"

    TARBALL_NAME="hikari-llvm-alpine-amd64-$(date +%Y%m%d).tar.gz"

    if tar -czf "$TARBALL_NAME" -C "$OUTPUT_DIR" .; then
        echo -e "${GREEN}✓ Tarball created: ${TARBALL_NAME}${NC}"
        echo -e "${BLUE}  Size: $(du -h "$TARBALL_NAME" | cut -f1)${NC}"
    else
        echo -e "${RED}Error: Failed to create tarball${NC}"
    fi
    echo ""
}

# Main execution
main() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi

    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        echo -e "${RED}Error: Dockerfile not found in current directory${NC}"
        exit 1
    fi

    # Execute based on flags
    if [ "$EXTRACT_ONLY" = true ]; then
        extract_binaries
    elif [ "$BUILD_ONLY" = true ]; then
        build_image
    else
        build_image
        extract_binaries
    fi

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Build completed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Usage examples:${NC}"
    echo -e "  # Use clang with obfuscation"
    echo -e "  ${OUTPUT_DIR}/bin/clang -mllvm -irobf-indbr -mllvm -irobf-icall main.c"
    echo ""
    echo -e "  # Check available obfuscation passes"
    echo -e "  ${OUTPUT_DIR}/bin/clang -Xclang -load -Xclang LLVMObfuscation.so --help"
    echo ""
}

main