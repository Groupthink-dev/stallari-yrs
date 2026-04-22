.PHONY: build build-macos build-ios universal headers clean test

RUST_DIR := rust
LIB_DIR := lib
HEADER_DIR := Sources/CStallariYRS/include

# Rust target triples
TARGET_MACOS_ARM := aarch64-apple-darwin
TARGET_IOS_ARM := aarch64-apple-ios

# Output library name (must match Cargo.toml [package] name with hyphens → underscores)
LIB_NAME := libstallari_yrs.a

## Build for the current host (macOS arm64) and generate headers
build: build-macos headers
	@echo "==> Build complete. Run 'swift test' to verify."

## Build for all Apple targets and generate headers
universal: build-macos build-ios headers
	@echo "==> Universal build complete (macOS arm64 + iOS arm64)."

## Build Rust static library for macOS arm64
build-macos:
	@echo "==> Building Rust for $(TARGET_MACOS_ARM)..."
	cd $(RUST_DIR) && cargo build --release --target $(TARGET_MACOS_ARM)
	@mkdir -p $(LIB_DIR)
	cp $(RUST_DIR)/target/$(TARGET_MACOS_ARM)/release/$(LIB_NAME) $(LIB_DIR)/$(LIB_NAME)
	@echo "==> macOS arm64 static library → $(LIB_DIR)/$(LIB_NAME)"

## Build Rust static library for iOS arm64
build-ios:
	@echo "==> Building Rust for $(TARGET_IOS_ARM)..."
	cd $(RUST_DIR) && cargo build --release --target $(TARGET_IOS_ARM)
	@mkdir -p $(LIB_DIR)/ios
	cp $(RUST_DIR)/target/$(TARGET_IOS_ARM)/release/$(LIB_NAME) $(LIB_DIR)/ios/$(LIB_NAME)
	@echo "==> iOS arm64 static library → $(LIB_DIR)/ios/$(LIB_NAME)"

## Regenerate C header from Rust source
headers:
	@echo "==> Generating C header via cbindgen..."
	cd $(RUST_DIR) && cbindgen --config cbindgen.toml --crate stallari-yrs --output ../$(HEADER_DIR)/yrs_ffi.h
	@echo "==> Header → $(HEADER_DIR)/yrs_ffi.h"

## Run Swift tests (requires build-macos first)
test: build
	swift test

## Clean all build artifacts
clean:
	cd $(RUST_DIR) && cargo clean
	rm -rf $(LIB_DIR)
	swift package clean
