#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Default Python version
PYTHON_VERSION="${1:-3.12}"

# Valid Python versions
VALID_VERSIONS=("3.8" "3.9" "3.10" "3.11" "3.12")

# Validate Python version
if [[ ! " ${VALID_VERSIONS[*]} " =~ " ${PYTHON_VERSION} " ]]; then
    echo "Error: Invalid Python version '${PYTHON_VERSION}'"
    echo "Valid versions: ${VALID_VERSIONS[*]}"
    exit 1
fi

# Determine base image based on Python version
# Python 3.12+ requires Amazon Linux 2023
if [[ "$PYTHON_VERSION" == "3.12" ]]; then
    BASE_IMAGE="amazonlinux:2023"
else
    BASE_IMAGE="amazonlinux:2"
fi

# Define variables
DOCKER_IMAGE_NAME="lambda-layer-builder-py${PYTHON_VERSION}"
OUTPUT_ZIP="python-layer-${PYTHON_VERSION}.zip"

echo "============================================"
echo "Building Lambda Layer for Python ${PYTHON_VERSION}"
echo "Base image: ${BASE_IMAGE}"
echo "Output file: ${OUTPUT_ZIP}"
echo "============================================"

# Step 1: Build the Docker image with build args
echo "Building the Docker image..."
docker build \
    --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
    --build-arg BASE_IMAGE="${BASE_IMAGE}" \
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
