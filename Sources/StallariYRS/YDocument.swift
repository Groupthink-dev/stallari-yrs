import CStallariYRS
import Foundation

/// A collaborative CRDT document backed by the yrs Rust library.
///
/// Each `YDocument` holds an opaque pointer to a Rust `Doc`. The document
/// is freed automatically when this object is deallocated. All mutations
/// go through `YText` operations obtained from this document.
///
/// Thread safety: yrs uses internal `RwLock`, but callers should serialise
/// write access (e.g. via an actor) to avoid contention.
public final class YDocument: @unchecked Sendable {
    private var handle: OpaquePointer?

    /// Create a new document with a random client ID.
    public init() {
        self.handle = yrs_doc_new()
    }

    /// Create a new document with a specific client ID.
    /// Use this for deterministic author attribution.
    public init(clientID: UInt64) {
        self.handle = yrs_doc_new_with_client_id(clientID)
    }

    deinit {
        if let h = handle {
            yrs_doc_free(h)
        }
    }

    /// The client ID assigned to this document.
    public var clientID: UInt64 {
        guard let h = handle else { return 0 }
        return yrs_doc_client_id(h)
    }

    /// Get or create a named collaborative text type.
    ///
    /// The returned `YText` is valid for the lifetime of this document.
    public func getText(named name: String) throws -> YText {
        guard let h = handle else { throw YRSError.documentFreed }
        let textRef = name.withCString { cName in
            yrs_doc_get_text(h, cName)
        }
        guard let ref_ = textRef else { throw YRSError.ffiError("failed to get text '\(name)'") }
        return YText(doc: self, handle: ref_, name: name)
    }

    // MARK: - State Encoding

    /// Encode the full document state as a binary update (V2 encoding).
    public func encodeStateAsUpdate() throws -> Data {
        guard let h = handle else { throw YRSError.documentFreed }
        var len: UInt = 0
        guard let buf = yrs_doc_encode_state_as_update_v2(h, &len), len > 0 else {
            throw YRSError.encodingFailed
        }
        let data = Data(bytes: buf, count: Int(len))
        yrs_buf_free(buf)
        return data
    }

    /// Apply a binary update (V2 encoding) from a remote peer.
    public func applyUpdate(_ data: Data) throws {
        guard let h = handle else { throw YRSError.documentFreed }
        let result = data.withUnsafeBytes { rawBuf -> Int32 in
            guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return yrs_doc_apply_update_v2(h, ptr, UInt(rawBuf.count))
        }
        if result != 0 {
            throw YRSError.decodingFailed
        }
    }

    /// Encode the document's state vector for sync negotiation.
    public func encodeStateVector() throws -> Data {
        guard let h = handle else { throw YRSError.documentFreed }
        var len: UInt = 0
        guard let buf = yrs_doc_encode_state_vector(h, &len), len > 0 else {
            throw YRSError.encodingFailed
        }
        let data = Data(bytes: buf, count: Int(len))
        yrs_buf_free(buf)
        return data
    }

    /// Compute the diff (update) needed to bring a peer from the given
    /// state vector to the current document state (V2 encoding).
    public func encodeDiff(from stateVector: Data) throws -> Data {
        guard let h = handle else { throw YRSError.documentFreed }
        var outLen: UInt = 0
        let buf = stateVector.withUnsafeBytes { rawBuf -> UnsafeMutablePointer<UInt8>? in
            guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }
            return yrs_doc_encode_diff_v2(h, ptr, UInt(rawBuf.count), &outLen)
        }
        guard let buf, outLen > 0 else {
            throw YRSError.encodingFailed
        }
        let data = Data(bytes: buf, count: Int(outLen))
        yrs_buf_free(buf)
        return data
    }

    // MARK: - Internal

    internal var rawHandle: OpaquePointer? { handle }
}
