import Testing
@testable import StallariYRS

@Suite("YText Tests")
struct YTextTests {

    @Test("Insert and read text")
    func insertAndRead() throws {
        let doc = YDocument(clientID: 1)
        let text = try doc.getText(named: "content")

        try text.insert(at: 0, text: "Hello")
        #expect(try text.toString() == "Hello")
        #expect(text.length == 5)
    }

    @Test("Insert at middle")
    func insertAtMiddle() throws {
        let doc = YDocument(clientID: 1)
        let text = try doc.getText(named: "content")

        try text.insert(at: 0, text: "Hllo")
        try text.insert(at: 1, text: "e")
        #expect(try text.toString() == "Hello")
    }

    @Test("Delete characters")
    func delete() throws {
        let doc = YDocument(clientID: 1)
        let text = try doc.getText(named: "content")

        try text.insert(at: 0, text: "Hello World")
        try text.delete(at: 5, length: 6)
        #expect(try text.toString() == "Hello")
        #expect(text.length == 5)
    }

    @Test("Multiple text types in same document")
    func multipleTexts() throws {
        let doc = YDocument(clientID: 1)
        let title = try doc.getText(named: "title")
        let body = try doc.getText(named: "body")

        try title.insert(at: 0, text: "My Title")
        try body.insert(at: 0, text: "Body content here.")

        #expect(try title.toString() == "My Title")
        #expect(try body.toString() == "Body content here.")

        // Both sync together in one update
        let doc2 = YDocument(clientID: 2)
        try doc2.applyUpdate(try doc.encodeStateAsUpdate())

        let title2 = try doc2.getText(named: "title")
        let body2 = try doc2.getText(named: "body")
        #expect(try title2.toString() == "My Title")
        #expect(try body2.toString() == "Body content here.")
    }

    @Test("Unicode text handling")
    func unicode() throws {
        let doc = YDocument(clientID: 1)
        let text = try doc.getText(named: "content")

        try text.insert(at: 0, text: "Hello \u{1F30D}")  // globe emoji
        let content = try text.toString()
        #expect(content.contains("\u{1F30D}"))
    }

    @Test("Empty text has length 0")
    func emptyText() throws {
        let doc = YDocument(clientID: 1)
        let text = try doc.getText(named: "content")
        #expect(text.length == 0)
        #expect(try text.toString() == "")
    }

    @Test("Sequential inserts from same client")
    func sequentialInserts() throws {
        let doc = YDocument(clientID: 1)
        let text = try doc.getText(named: "content")

        try text.insert(at: 0, text: "A")
        try text.insert(at: 1, text: "B")
        try text.insert(at: 2, text: "C")
        #expect(try text.toString() == "ABC")
    }
}
