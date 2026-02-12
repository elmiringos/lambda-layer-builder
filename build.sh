#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Default Python version
PYTHON_VERSION="${1:-3.12}"

# Build from source flag (compile packages instead of using pre-built wheels)
BUILD_FROM_SOURCE=$(echo "${2:-false}" | tr '[:upper:]' '[:lower:]')
if [[ "${BUILD_FROM_SOURCE}" != "true" ]]; then
    BUILD_FROM_SOURCE="false"
fi

# Architecture (x86_64 or arm64)
ARCH="${3:-x86_64}"

# Valid Python versions
VALID_VERSIONS=("3.8" "3.9" "3.10" "3.11" "3.12")

# Valid architectures
VALID_ARCHS=("x86_64" "arm64")

# Validate Python version
if [[ ! " ${VALID_VERSIONS[*]} " =~ " ${PYTHON_VERSION} " ]]; then
    echo "Error: Invalid Python version '${PYTHON_VERSION}'"
    echo "Valid versions: ${VALID_VERSIONS[*]}"
    exit 1
fi

# Validate architecture
if [[ ! " ${VALID_ARCHS[*]} " =~ " ${ARCH} " ]]; then
    echo "Error: Invalid architecture '${ARCH}'"
    echo "Valid architectures: ${VALID_ARCHS[*]}"
    exit 1
fi

# Map architecture to Docker platform
if [[ "${ARCH}" == "x86_64" ]]; then
    DOCKER_PLATFORM="linux/amd64"
else
    DOCKER_PLATFORM="linux/arm64"
fi

# Define variables
DOCKER_IMAGE_NAME="lambda-layer-builder-py${PYTHON_VERSION}-${ARCH}"

# Output zip: use 4th arg if provided, otherwise default
OUTPUT_ZIP="${4:-python-layer-${PYTHON_VERSION}-${ARCH}.zip}"

# Validate output filename: must be a plain filename (no path separators or ..)
if [[ "${OUTPUT_ZIP}" == */* ]] || [[ "${OUTPUT_ZIP}" == *..* ]]; then
    echo "Error: OUTPUT_ZIP must be a plain filename (no paths). Got: '${OUTPUT_ZIP}'"
    exit 1
fi

echo "============================================"
echo "Building Lambda Layer for Python ${PYTHON_VERSION}"
echo "Architecture: ${ARCH} (${DOCKER_PLATFORM})"
echo "Build from source: ${BUILD_FROM_SOURCE}"
echo "Output file: ${OUTPUT_ZIP}"
echo "============================================"

# Step 1: Build the Docker image with build args
echo "Building the Docker image..."
docker build \
    --platform "${DOCKER_PLATFORM}" \
    --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
    --build-arg BUILD_FROM_SOURCE="${BUILD_FROM_SOURCE}" \
    -t "${DOCKER_IMAGE_NAME}" .

# Step 2: Run the container to extract the Lambda layer zip file
echo "Extracting the Lambda layer zip file..."
CONTAINER_ID=$(docker create "${DOCKER_IMAGE_NAME}" /nonexistent)
docker cp "${CONTAINER_ID}:/layer.zip" "${OUTPUT_ZIP}"
docker rm "${CONTAINER_ID}"

# Step 3: Display layer info
LAYER_SIZE=$(du -h "${OUTPUT_ZIP}" | cut -f1)
echo "============================================"
echo "Lambda layer zip file created: ${OUTPUT_ZIP}"
echo "Layer size: ${LAYER_SIZE}"
echo "============================================"
