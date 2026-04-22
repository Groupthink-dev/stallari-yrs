import CStallariYRS
import Foundation

/// A collaborative text type within a `YDocument`.
///
/// Operations on `YText` are CRDT-merged across documents.
/// Each insert/delete creates a yrs update that can be encoded
/// and transmitted to remote peers.
///
/// The `YText` holds a reference to its parent document — the
/// document must remain alive for the duration of use.
public final class YText: @unchecked Sendable {
    private weak var doc: YDocument?
    private var handle: OpaquePointer?
    private let textName: String

    internal init(doc: YDocument, handle: OpaquePointer, name: String) {
        self.doc = doc
        self.handle = handle
        self.textName = name
    }

    deinit {
        if let h = handle {
            yrs_text_free(h)
        }
    }

    /// The name of this text type within the document.
    public var name: String { textName }

    /// Insert text at the given UTF-8 offset.
    public func insert(at index: UInt32, text: String) throws {
        guard let docHandle = doc?.rawHandle, let h = handle else {
            throw YRSError.documentFreed
        }
        let result = text.withCString { cStr in
            yrs_text_insert(docHandle, h, index, cStr)
        }
        if result != 0 {
            throw YRSError.ffiError("text insert failed at index \(index)")
        }
    }

    /// Delete `length` characters starting at `index`.
    public func delete(at index: UInt32, length: UInt32) throws {
        guard let docHandle = doc?.rawHandle, let h = handle else {
            throw YRSError.documentFreed
        }
        let result = yrs_text_delete(docHandle, h, index, length)
        if result != 0 {
            throw YRSError.ffiError("text delete failed at index \(index), length \(length)")
        }
    }

    /// Get the full text content as a String.
    public func toString() throws -> String {
        guard let docHandle = doc?.rawHandle, let h = handle else {
            throw YRSError.documentFreed
        }
        guard let cStr = yrs_text_to_string(docHandle, h) else {
            throw YRSError.ffiError("text toString failed")
        }
        let result = String(cString: cStr)
        yrs_string_free(cStr)
        return result
    }

    /// The length of the text in characters.
    public var length: UInt32 {
        guard let docHandle = doc?.rawHandle, let h = handle else { return 0 }
        return yrs_text_len(docHandle, h)
    }
}
