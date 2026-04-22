# stallari-yrs — Yrs CRDT FFI Wrapper

Swift Package Manager library wrapping the [yrs](https://github.com/y-crdt/y-crdt) Rust CRDT library via C FFI. Provides `YDocument`, `YText`, `YAwareness` for collaborative document editing in Stallari.

## Build

Requires Rust toolchain with Apple targets:

```sh
rustup target add aarch64-apple-darwin aarch64-apple-ios
cargo install cbindgen
```

Build the Rust static library and generate headers:

```sh
make build       # macOS arm64 only
make universal   # macOS + iOS arm64
```

Run tests:

```sh
make test        # builds Rust then runs swift test
```

## Architecture

```
rust/src/lib.rs          → C FFI bridge (#[no_mangle] pub extern "C")
Sources/CStallariYRS/    → C module (module.modulemap + yrs_ffi.h)
Sources/StallariYRS/     → Swift wrappers (YDocument, YText, YAwareness)
lib/                     → Compiled static libraries (git-ignored)
```

The Rust crate compiles to a static library (`libstallari_yrs.a`). cbindgen generates the C header. Swift imports the C module and wraps it in idiomatic types.

## Memory Management

Every `yrs_*_new` has a corresponding `yrs_*_free`. Swift classes call free in `deinit`. Buffers returned by FFI functions must be freed with `yrs_buf_free` or `yrs_string_free`.

`YDocument` is `@unchecked Sendable` — yrs uses internal RwLock. Callers should serialise write access via an actor (PadEngine in stallari-harness).

## Consumer

stallari-harness consumes this as a local SPM dependency:

```swift
.package(path: "../stallari-yrs")
```
