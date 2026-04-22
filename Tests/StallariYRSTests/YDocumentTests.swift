import Testing
@testable import StallariYRS

@Suite("YDocument Tests")
struct YDocumentTests {

    @Test("Create document with random client ID")
    func createDocument() throws {
        let doc = YDocument()
        #expect(doc.clientID > 0)
    }

    @Test("Create document with specific client ID")
    func createWithClientID() throws {
        let doc = YDocument(clientID: 42)
        #expect(doc.clientID == 42)
    }

    @Test("Encode and apply update roundtrip")
    func encodeApplyRoundtrip() throws {
        let doc1 = YDocument(clientID: 1)
        let text1 = try doc1.getText(named: "content")
        try text1.insert(at: 0, text: "Hello, world!")

        let update = try doc1.encodeStateAsUpdate()
        #expect(update.count > 0)

        let doc2 = YDocument(clientID: 2)
        try doc2.applyUpdate(update)

        let text2 = try doc2.getText(named: "content")
        let content = try text2.toString()
        #expect(content == "Hello, world!")
    }

    @Test("State vector encode/decode")
    func stateVector() throws {
        let doc = YDocument(clientID: 1)
        let text = try doc.getText(named: "content")
        try text.insert(at: 0, text: "test")

        let sv = try doc.encodeStateVector()
        #expect(sv.count > 0)
    }

    @Test("Diff encoding sends only missing changes")
    func diffEncoding() throws {
        let doc1 = YDocument(clientID: 1)
        let text1 = try doc1.getText(named: "content")
        try text1.insert(at: 0, text: "Hello")

        // doc2 syncs up
        let doc2 = YDocument(clientID: 2)
        let update1 = try doc1.encodeStateAsUpdate()
        try doc2.applyUpdate(update1)

        // doc1 adds more text
        try text1.insert(at: 5, text: " World")

        // Compute diff from doc2's state vector
        let sv2 = try doc2.encodeStateVector()
        let diff = try doc1.encodeDiff(from: sv2)
        #expect(diff.count > 0)

        // Apply diff — should only contain " World"
        try doc2.applyUpdate(diff)
        let text2 = try doc2.getText(named: "content")
        let content = try text2.toString()
        #expect(content == "Hello World")
    }

    @Test("Two documents with concurrent edits merge correctly")
    func concurrentMerge() throws {
        let doc1 = YDocument(clientID: 1)
        let text1 = try doc1.getText(named: "content")
        try text1.insert(at: 0, text: "Hello")

        // Sync doc2
        let doc2 = YDocument(clientID: 2)
        try doc2.applyUpdate(try doc1.encodeStateAsUpdate())

        // Concurrent edits
        try text1.insert(at: 5, text: " from A")
        let text2 = try doc2.getText(named: "content")
        try text2.insert(at: 5, text: " from B")

        // Exchange updates
        let update1 = try doc1.encodeStateAsUpdate()
        let update2 = try doc2.encodeStateAsUpdate()

        try doc1.applyUpdate(update2)
        try doc2.applyUpdate(update1)

        // Both should converge to the same text
        let result1 = try text1.toString()
        let result2 = try text2.toString()
        #expect(result1 == result2)
        // Both "from A" and "from B" should be present
        #expect(result1.contains("from A"))
        #expect(result1.contains("from B"))
    }

    @Test("Empty document encodes successfully")
    func emptyDocumentEncode() throws {
        let doc = YDocument()
        let update = try doc.encodeStateAsUpdate()
        #expect(update.count > 0)

        let sv = try doc.encodeStateVector()
        #expect(sv.count > 0)
    }
}
