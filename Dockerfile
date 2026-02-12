# Build arguments for multi-version support
ARG PYTHON_VERSION=3.12
ARG BASE_IMAGE=amazonlinux:2
ARG BUILD_FROM_SOURCE=false

# Use parameterized base image to match AWS Lambda runtime environment
FROM ${BASE_IMAGE} AS builder

ARG PYTHON_VERSION
ARG BUILD_FROM_SOURCE

# Install Python and dependencies
# Conditional logic: yum (Amazon Linux 2) vs dnf (Amazon Linux 2023)
# When BUILD_FROM_SOURCE=true, also install compiler toolchain
RUN if command -v amazon-linux-extras &> /dev/null; then \
        yum update -y && \
        amazon-linux-extras enable python${PYTHON_VERSION} && \
        yum install -y python${PYTHON_VERSION} zip && \
        if [ "${BUILD_FROM_SOURCE}" = "true" ]; then \
            yum install -y \
                python${PYTHON_VERSION}-devel \
                gcc \
                gcc-c++ \
                make \
                findutils \
                binutils \
                openssl-devel; \
        fi && \
        python${PYTHON_VERSION} -m ensurepip && \
        python${PYTHON_VERSION} -m pip install --upgrade pip; \
    else \
        dnf update -y && \
        dnf install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-pip zip && \
        if [ "${BUILD_FROM_SOURCE}" = "true" ]; then \
            dnf install -y \
                python${PYTHON_VERSION}-devel \
                gcc \
                gcc-c++ \
                make \
                findutils \
                binutils \
                openssl-devel; \
        fi && \
        python${PYTHON_VERSION} -m pip install --upgrade pip; \
    fi

# Set the working directory
WORKDIR /app

# Copy requirements.txt into the container
COPY requirements.txt .

# Install dependencies into a 'python' folder for the Lambda layer structure
# When BUILD_FROM_SOURCE=true, compile from source using --no-binary :all:
RUN mkdir -p /app/python && \
    if [ "${BUILD_FROM_SOURCE}" = "true" ]; then \
        python${PYTHON_VERSION} -m pip install \
            --no-cache-dir \
            --no-binary :all: \
            -r requirements.txt \
            -t /app/python; \
    else \
        python${PYTHON_VERSION} -m pip install \
            --no-cache-dir \
            -r requirements.txt \
            -t /app/python; \
    fi

# Strip and clean when building from source
RUN if [ "${BUILD_FROM_SOURCE}" = "true" ]; then \
        find /app/python -name "*.so" -exec strip --strip-unneeded {} + 2>/dev/null || true; \
        find /app/python -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true; \
        find /app/python -name "*.pyc" -delete 2>/dev/null || true; \
        find /app/python -name "*.pyo" -delete 2>/dev/null || true; \
        find /app/python -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true; \
        find /app/python -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true; \
        find /app/python -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true; \
        find /app/python -type d -name "test" -exec rm -rf {} + 2>/dev/null || true; \
        find /app/python -type d -name "docs" -exec rm -rf {} + 2>/dev/null || true; \
        find /app/python -type d -name "doc" -exec rm -rf {} + 2>/dev/null || true; \
    fi

# Package the dependencies into a zip file
RUN zip -r layer.zip python

# Final stage - Create a minimal container with just the zip file
FROM scratch
COPY --from=builder /app/layer.zip /
