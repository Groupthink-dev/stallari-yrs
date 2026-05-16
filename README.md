# stallari-yrs

Swift Package Manager library wrapping the [yrs](https://github.com/y-crdt/y-crdt) Rust CRDT library via C FFI. Provides `YDocument`, `YText`, `YAwareness` for collaborative document editing in Stallari.

## Build

Requires Rust toolchain with Apple targets (pinned via `rust-toolchain.toml`):

```sh
rustup target add aarch64-apple-darwin aarch64-apple-ios
cargo install cbindgen
```

Local development build (rebuilds the Rust static lib + Swift wrapper from source):

```sh
make build              # macOS arm64 only
make universal          # macOS + iOS arm64
make release-xcframework  # production: deterministic xcframework + SHA-256 (DD-295 Phase C)
```

Run tests:

```sh
make test
```

## Binary distribution

Per [DD-295 Phase C amendment](../master-ai/atlas/utilities/agent-harness/specs/2026-05-16-dd-295-phase-c.md) § "Binary-distributed siblings", consumers of this package resolve `CStallariYRS` as a SwiftPM `binaryTarget(url:, checksum:)` pointing at the `stallari_yrs.xcframework.zip` asset attached to each tagged GH Release on `groupthink-dev/stallari-yrs`. The published xcframework bundles both `macos-arm64` and `ios-arm64` static-library variants built with `cargo build --release --locked` against the pinned Rust toolchain. `make release-xcframework` builds the asset; `make verify-xcframework` validates determinism (two consecutive builds must produce identical SHA-256). Release assets are append-only — never deleted, never re-uploaded with `--clobber` — to preserve `swift package resolve` for any historical consumer commit.

## Architecture

```
rust/src/lib.rs          → C FFI bridge (#[no_mangle] pub extern "C")
Sources/CStallariYRS/    → C module (module.modulemap + yrs_ffi.h) — input to xcframework build
Sources/StallariYRS/     → Swift wrappers (YDocument, YText, YAwareness)
lib/                     → Compiled static libraries (git-ignored, populated by `make build`)
build/                   → xcframework + zip output (git-ignored, populated by `make release-xcframework`)
```

## Memory Management

Every `yrs_*_new` has a corresponding `yrs_*_free`. Swift classes call free in `deinit`. Buffers returned by FFI functions must be freed with `yrs_buf_free` or `yrs_string_free`.

`YDocument` is `@unchecked Sendable` — yrs uses internal `RwLock`. Callers should serialise write access via an actor (`PadEngine` in stallari-harness).
