/// Errors from the yrs FFI layer.
public enum YRSError: Error, Sendable {
    /// An FFI call returned an error code.
    case ffiError(String)
    /// Failed to encode document state.
    case encodingFailed
    /// Failed to decode an incoming update or state vector.
    case decodingFailed
    /// Operation attempted on a document that has been freed.
    case documentFreed
}
