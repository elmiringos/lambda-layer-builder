# Lambda Layer Builder

Build AWS Lambda layers with Python dependencies.

## Requirements
- Docker
- Make

## Usage
1. Add packages to `requirements.txt`
2. Run `make build`

## Make Targets
- `make build` - Build layer (Python 3.12, x86_64)
- `make build ARCH=arm64` - Build for ARM64 architecture
- `make build BUILD_FROM_SOURCE=true` - Build from source for smaller zip
- `make build OUTPUT_ZIP=my-layer.zip` - Build with custom output filename
- `make clean` - Remove artifacts
- `make upload` - Publish to AWS

## Options
| Variable | Default | Description |
|---|---|---|
| `PYTHON_VERSION` | 3.12 | Python version to build |
| `ARCH` | x86_64 | Target architecture (`x86_64` or `arm64`) |
| `OUTPUT_ZIP` | | Custom output zip filename (default: `python-layer-<ver>-<arch>.zip`) |
| `BUILD_FROM_SOURCE` | | Set to `true` to compile from source, strip binaries, and remove unnecessary files for smaller layers |
| `AWS_REGION` | us-east-1 | AWS region for upload |
| `LAYER_NAME` | python-dependencies | Lambda layer name prefix |
