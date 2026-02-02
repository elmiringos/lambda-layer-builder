# Lambda Layer Builder

Build AWS Lambda layers with Python dependencies.

## Requirements
- Docker
- Make

## Usage
1. Add packages to `requirements.txt`
2. Run `make build`

## Make Targets
- `make build` - Build layer (Python 3.12)
- `make clean` - Remove artifacts
- `make upload` - Publish to AWS
