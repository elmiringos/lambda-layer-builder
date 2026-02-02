# Build arguments for multi-version support
ARG PYTHON_VERSION=3.8
ARG BASE_IMAGE=amazonlinux:2

# Use parameterized base image to match AWS Lambda runtime environment
FROM ${BASE_IMAGE} AS builder

ARG PYTHON_VERSION

# Install Python and dependencies
# Conditional logic: yum (Amazon Linux 2) vs dnf (Amazon Linux 2023)
RUN if command -v amazon-linux-extras &> /dev/null; then \
        yum update -y && \
        amazon-linux-extras enable python${PYTHON_VERSION} && \
        yum install -y python${PYTHON_VERSION} zip && \
        python${PYTHON_VERSION} -m ensurepip && \
        python${PYTHON_VERSION} -m pip install --upgrade pip; \
    else \
        dnf update -y && \
        dnf install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-pip zip && \
        python${PYTHON_VERSION} -m pip install --upgrade pip; \
    fi

# Set the working directory
WORKDIR /app

# Copy requirements.txt into the container
COPY requirements.txt .

# Install dependencies into a 'python' folder for the Lambda layer structure
RUN mkdir -p /app/python && \
    python${PYTHON_VERSION} -m pip install --no-cache-dir -r requirements.txt -t /app/python

# Package the dependencies into a zip file
RUN zip -r layer.zip python

# Final stage - Create a minimal container with just the zip file
FROM scratch
COPY --from=builder /app/layer.zip /

