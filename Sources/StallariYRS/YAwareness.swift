import CStallariYRS
import Foundation

/// Manages per-client awareness state (cursor positions, selections, presence).
///
/// The awareness protocol is separate from document state — it's ephemeral
/// presence data that doesn't persist. Each client sets its local state
/// (typically JSON with cursor position and user info) and can encode/apply
/// updates from remote clients.
///
/// Wire format: `[8 bytes client_id BE][4 bytes state_len BE][state bytes]`
public final class YAwareness: @unchecked Sendable {
    private var handle: OpaquePointer?

    /// Create a new awareness instance for the given client ID.
    public init(clientID: UInt64) {
        self.handle = yrs_awareness_new(clientID)
    }

    deinit {
        if let h = handle {
            yrs_awareness_free(h)
        }
    }

    /// Set the local awareness state.
    ///
    /// Typically JSON-encoded: `{"cursor": 42, "selection": [10, 20], "user": {"name": "Piers", "colour": 3}}`
    public func setLocalState(_ data: Data) {
        guard let h = handle else { return }
        data.withUnsafeBytes { rawBuf in
            guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            yrs_awareness_set_local_state(h, ptr, UInt(rawBuf.count))
        }
    }

    /// Apply a remote awareness update received from another client.
    public func applyUpdate(_ data: Data) throws {
        guard let h = handle else { throw YRSError.documentFreed }
        let result = data.withUnsafeBytes { rawBuf -> Int32 in
            guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return -1
            }
            return yrs_awareness_apply_update(h, ptr, UInt(rawBuf.count))
        }
        if result != 0 {
            throw YRSError.decodingFailed
        }
    }

    /// Encode the local awareness state for transmission to peers.
    public func encodeUpdate() throws -> Data {
        guard let h = handle else { throw YRSError.documentFreed }
        var len: UInt = 0
        guard let buf = yrs_awareness_encode_update(h, &len), len > 0 else {
            throw YRSError.encodingFailed
        }
        let data = Data(bytes: buf, count: Int(len))
        yrs_buf_free(buf)
        return data
    }

    /// The number of known clients (including self).
    public var clientCount: UInt32 {
        guard let h = handle else { return 0 }
        return yrs_awareness_client_count(h)
    }

    /// Get the awareness state for a specific client.
    /// Returns nil if the client is unknown.
    public func clientState(for clientID: UInt64) -> Data? {
        guard let h = handle else { return nil }
        var len: UInt = 0
        guard let buf = yrs_awareness_get_client_state(h, clientID, &len), len > 0 else {
            return nil
        }
        let data = Data(bytes: buf, count: Int(len))
        yrs_buf_free(buf)
        return data
    }
}
