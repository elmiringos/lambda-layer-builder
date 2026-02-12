# Lambda Layer Builder Makefile
# Supports Python versions: 3.8, 3.9, 3.10, 3.11, 3.12

# Default Python version
PYTHON_VERSION ?= 3.12

# Valid Python versions
VALID_VERSIONS := 3.8 3.9 3.10 3.11 3.12

# AWS settings (can be overridden via environment or command line)
AWS_REGION ?= us-east-1
LAYER_NAME ?= python-dependencies

# Build from source flag (set to "true" to compile packages from source for smaller zip)
BUILD_FROM_SOURCE ?=

# Architecture (x86_64 or arm64)
ARCH ?= x86_64

# Custom output zip filename (optional, must be a plain filename)
OUTPUT_ZIP ?=

# Derived variables
_DEFAULT_ZIP := python-layer-$(PYTHON_VERSION)-$(ARCH).zip
_EFFECTIVE_ZIP := $(if $(OUTPUT_ZIP),$(OUTPUT_ZIP),$(_DEFAULT_ZIP))
LAMBDA_RUNTIME := python$(PYTHON_VERSION)

.PHONY: build clean help test upload list-layers build-all clean-all validate-version

# Default target
build: validate-version
	@echo "Building Lambda layer for Python $(PYTHON_VERSION) ($(ARCH))..."
	@./build.sh "$(PYTHON_VERSION)" "$(BUILD_FROM_SOURCE)" "$(ARCH)" "$(OUTPUT_ZIP)"

# Build all supported Python versions
build-all:
	@for version in $(VALID_VERSIONS); do \
		echo ""; \
		echo "========================================"; \
		echo "Building for Python $$version ($(ARCH))..."; \
		echo "========================================"; \
		./build.sh "$$version" "$(BUILD_FROM_SOURCE)" "$(ARCH)"; \
	done

# Clean generated files for specific version
clean: validate-version
	@echo "Cleaning build artifacts for Python $(PYTHON_VERSION) ($(ARCH))..."
	@rm -f $(_EFFECTIVE_ZIP)
	@docker rmi lambda-layer-builder-py$(PYTHON_VERSION)-$(ARCH) 2>/dev/null || true
	@echo "Clean complete."

# Clean all generated files
clean-all:
	@echo "Cleaning all build artifacts..."
	@rm -f python-layer-*.zip
	@for version in $(VALID_VERSIONS); do \
		docker rmi lambda-layer-builder-py$$version-x86_64 2>/dev/null || true; \
		docker rmi lambda-layer-builder-py$$version-arm64 2>/dev/null || true; \
	done
	@echo "Clean complete."

# Display help information
help:
	@echo ""
	@echo "Lambda Layer Builder"
	@echo "===================="
	@echo ""
	@echo "Usage: make [target] [PYTHON_VERSION=X.Y]"
	@echo ""
	@echo "Targets:"
	@echo "  build        Build Lambda layer for specified Python version (default: 3.12)"
	@echo "  build-all    Build Lambda layers for all supported Python versions"
	@echo "  clean        Remove build artifacts for specified Python version"
	@echo "  clean-all    Remove all build artifacts"
	@echo "  test         Validate the built layer structure and size"
	@echo "  upload       Upload layer to AWS Lambda"
	@echo "  list-layers  List existing Lambda layers in AWS"
	@echo "  help         Display this help message"
	@echo ""
	@echo "Supported Python Versions: $(VALID_VERSIONS)"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make build PYTHON_VERSION=3.11"
	@echo "  make build ARCH=arm64"
	@echo "  make build PYTHON_VERSION=3.11 ARCH=arm64"
	@echo "  make build OUTPUT_ZIP=my-layer.zip"
	@echo "  make build-all"
	@echo "  make test PYTHON_VERSION=3.11"
	@echo "  make upload PYTHON_VERSION=3.11 LAYER_NAME=my-layer"
	@echo "  make build BUILD_FROM_SOURCE=true"
	@echo "  make build PYTHON_VERSION=3.11 BUILD_FROM_SOURCE=true"
	@echo "  make clean-all"
	@echo ""
	@echo "Environment Variables:"
	@echo "  PYTHON_VERSION     Python version to build (default: 3.12)"
	@echo "  ARCH               Target architecture: x86_64 or arm64 (default: x86_64)"
	@echo "  OUTPUT_ZIP         Custom output zip filename (default: python-layer-<ver>-<arch>.zip)"
	@echo "  AWS_REGION         AWS region for upload/list (default: us-east-1)"
	@echo "  LAYER_NAME         Base name for the Lambda layer (default: python-dependencies)"
	@echo "  BUILD_FROM_SOURCE  Set to 'true' to compile from source for smaller zip"
	@echo ""

# Validate Python version
validate-version:
	@if ! echo "$(VALID_VERSIONS)" | grep -qw "$(PYTHON_VERSION)"; then \
		echo "Error: Invalid Python version '$(PYTHON_VERSION)'"; \
		echo "Valid versions: $(VALID_VERSIONS)"; \
		exit 1; \
	fi

# Test the built layer
test: validate-version
	@echo "Testing Lambda layer for Python $(PYTHON_VERSION) ($(ARCH))..."
	@echo ""
	@if [ ! -f "$(_EFFECTIVE_ZIP)" ]; then \
		echo "Error: Layer file $(_EFFECTIVE_ZIP) not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo "1. Layer file exists: $(_EFFECTIVE_ZIP)"
	@UNZIPPED_SIZE=$$(unzip -l "$(_EFFECTIVE_ZIP)" | tail -1 | awk '{print $$1}'); \
	UNZIPPED_MB=$$((UNZIPPED_SIZE / 1024 / 1024)); \
	echo "2. Unzipped size: $${UNZIPPED_MB}MB (limit: 250MB)"; \
	if [ $$UNZIPPED_MB -gt 250 ]; then \
		echo "   ERROR: Layer exceeds 250MB unzipped limit!"; \
		exit 1; \
	else \
		echo "   OK: Within size limit"; \
	fi
	@ZIP_SIZE=$$(stat -f%z "$(_EFFECTIVE_ZIP)" 2>/dev/null || stat -c%s "$(_EFFECTIVE_ZIP)"); \
	ZIP_MB=$$((ZIP_SIZE / 1024 / 1024)); \
	echo "3. Zipped size: $${ZIP_MB}MB"; \
	if [ $$ZIP_MB -gt 50 ]; then \
		echo "   WARNING: Layer exceeds 50MB. Must upload via S3."; \
	fi
	@if unzip -l "$(_EFFECTIVE_ZIP)" | grep -q "python/"; then \
		echo "4. Layer structure: OK (contains python/ directory)"; \
	else \
		echo "4. Layer structure: INVALID (missing python/ directory)"; \
		exit 1; \
	fi
	@echo ""
	@echo "5. Installed packages (top-level):"
	@unzip -l "$(_EFFECTIVE_ZIP)" | grep "python/[^/]*/" | sed 's/.*python\//   /' | cut -d'/' -f1 | sort -u | head -20
	@echo ""
	@echo "All tests passed!"

# Upload layer to AWS Lambda
upload: validate-version
	@echo "Uploading Lambda layer for Python $(PYTHON_VERSION) ($(ARCH))..."
	@if [ ! -f "$(_EFFECTIVE_ZIP)" ]; then \
		echo "Error: Layer file $(_EFFECTIVE_ZIP) not found. Run 'make build' first."; \
		exit 1; \
	fi
	@if ! command -v aws &> /dev/null; then \
		echo "Error: AWS CLI not found. Please install and configure it."; \
		exit 1; \
	fi
	@LAYER_FULL_NAME="$(LAYER_NAME)-py$$(echo $(PYTHON_VERSION) | tr -d '.')-$(ARCH)"; \
	echo "Publishing layer: $$LAYER_FULL_NAME"; \
	echo "Runtime: $(LAMBDA_RUNTIME)"; \
	echo "Architecture: $(ARCH)"; \
	echo "Region: $(AWS_REGION)"; \
	echo ""; \
	aws lambda publish-layer-version \
		--layer-name "$$LAYER_FULL_NAME" \
		--description "Python $(PYTHON_VERSION) $(ARCH) dependencies layer" \
		--zip-file "fileb://$(_EFFECTIVE_ZIP)" \
		--compatible-runtimes "$(LAMBDA_RUNTIME)" \
		--compatible-architectures "$(ARCH)" \
		--region "$(AWS_REGION)"

# List existing Lambda layers
list-layers:
	@echo "Listing Lambda layers in $(AWS_REGION)..."
	@if ! command -v aws &> /dev/null; then \
		echo "Error: AWS CLI not found. Please install and configure it."; \
		exit 1; \
	fi
	@aws lambda list-layers --region "$(AWS_REGION)" --output table
