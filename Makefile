SHELL := /bin/bash

.PHONY: build build-macos build-ios universal headers clean test \
        release-xcframework verify-xcframework clean-xcframework

RUST_DIR := rust
LIB_DIR := lib
HEADER_DIR := Sources/CStallariYRS/include
BUILD_DIR := build

# Rust target triples
TARGET_MACOS_ARM := aarch64-apple-darwin
TARGET_IOS_ARM := aarch64-apple-ios

# Output library name (must match Cargo.toml [package] name with hyphens → underscores)
LIB_NAME := libstallari_yrs.a

# Binary-distribution outputs (per DD-295 Phase C amendment)
XCFRAMEWORK_NAME := stallari_yrs.xcframework
XCFRAMEWORK_ZIP  := $(BUILD_DIR)/stallari_yrs.xcframework.zip

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

## --- DD-295 Phase C: binary distribution targets ---

## Build a release xcframework containing macOS arm64 + iOS arm64 static
## libraries, zip it, and print the SHA-256 (which becomes the
## Package.swift binaryTarget checksum).
release-xcframework: clean-xcframework
	@echo "==> Cargo build (macOS arm64, locked)..."
	cd $(RUST_DIR) && cargo build --release --locked --target $(TARGET_MACOS_ARM)
	@mkdir -p $(LIB_DIR)
	cp $(RUST_DIR)/target/$(TARGET_MACOS_ARM)/release/$(LIB_NAME) $(LIB_DIR)/$(LIB_NAME)
	@echo "==> Cargo build (iOS arm64, locked)..."
	cd $(RUST_DIR) && cargo build --release --locked --target $(TARGET_IOS_ARM)
	@mkdir -p $(LIB_DIR)/ios
	cp $(RUST_DIR)/target/$(TARGET_IOS_ARM)/release/$(LIB_NAME) $(LIB_DIR)/ios/$(LIB_NAME)
	@echo "==> Regenerating headers..."
	$(MAKE) headers
	@mkdir -p $(BUILD_DIR)
	@echo "==> Staging headers + module.modulemap for xcframework consumption..."
	@rm -rf $(BUILD_DIR)/staged-headers
	@mkdir -p $(BUILD_DIR)/staged-headers
	@cp $(HEADER_DIR)/yrs_ffi.h $(BUILD_DIR)/staged-headers/
	@printf 'module CStallariYRS {\n    header "yrs_ffi.h"\n    link "stallari_yrs"\n    export *\n}\n' > $(BUILD_DIR)/staged-headers/module.modulemap
	@echo "==> xcodebuild -create-xcframework..."
	xcodebuild -create-xcframework \
	    -library $(LIB_DIR)/$(LIB_NAME)        -headers $(BUILD_DIR)/staged-headers \
	    -library $(LIB_DIR)/ios/$(LIB_NAME)    -headers $(BUILD_DIR)/staged-headers \
	    -output  $(BUILD_DIR)/$(XCFRAMEWORK_NAME)
	@echo "==> Normalising Info.plist (sort AvailableLibraries for deterministic ordering)..."
	@python3 -c "import plistlib, sys; p = plistlib.load(open('$(BUILD_DIR)/$(XCFRAMEWORK_NAME)/Info.plist','rb')); p['AvailableLibraries'].sort(key=lambda x: x['LibraryIdentifier']); plistlib.dump(p, open('$(BUILD_DIR)/$(XCFRAMEWORK_NAME)/Info.plist','wb'), sort_keys=True)"
	@echo "==> Normalising mtimes for deterministic zip..."
	find $(BUILD_DIR)/$(XCFRAMEWORK_NAME) -exec touch -t 197001010000.00 {} +
	@echo "==> Zipping (deterministic: -X strips xattrs, -D strips dir entries, TZ=UTC + mtime-normalised input)..."
	cd $(BUILD_DIR) && TZ=UTC zip -r -X -D $(notdir $(XCFRAMEWORK_ZIP)) $(XCFRAMEWORK_NAME) >/dev/null
	@echo "==> SHA-256:"
	@shasum -a 256 $(XCFRAMEWORK_ZIP) | awk '{print "    " $$1 "  " $$2}'
	@echo "==> Done. Asset: $(XCFRAMEWORK_ZIP)"

## Verify a previously-built xcframework: structure + Info.plist + sha256 stability
verify-xcframework:
	@test -f $(XCFRAMEWORK_ZIP) || (echo "ERROR: $(XCFRAMEWORK_ZIP) absent. Run 'make release-xcframework' first." && exit 1)
	@echo "==> Structure check..."
	@cd $(BUILD_DIR) && unzip -l $(notdir $(XCFRAMEWORK_ZIP)) | grep -q "Info.plist" || (echo "ERROR: Info.plist missing" && exit 1)
	@cd $(BUILD_DIR) && unzip -l $(notdir $(XCFRAMEWORK_ZIP)) | grep -q "macos-arm64/$(LIB_NAME)" || (echo "ERROR: macOS variant missing" && exit 1)
	@cd $(BUILD_DIR) && unzip -l $(notdir $(XCFRAMEWORK_ZIP)) | grep -q "ios-arm64/$(LIB_NAME)" || (echo "ERROR: iOS variant missing" && exit 1)
	@echo "==> Determinism check — rebuild + compare SHA-256..."
	@cp $(XCFRAMEWORK_ZIP) /tmp/stallari_yrs.xcframework.zip.first
	@$(MAKE) release-xcframework >/dev/null
	@diff <(shasum -a 256 /tmp/stallari_yrs.xcframework.zip.first | awk '{print $$1}') \
	      <(shasum -a 256 $(XCFRAMEWORK_ZIP) | awk '{print $$1}') \
	    && echo "==> ✓ Deterministic build" \
	    || (echo "ERROR: Non-deterministic — SHA-256 differs across rebuilds" && exit 1)

## Remove xcframework build artefacts (does not touch rust/target — use 'make clean' for that)
clean-xcframework:
	rm -rf $(BUILD_DIR)
