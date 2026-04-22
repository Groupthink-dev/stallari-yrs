import Foundation
import Testing
@testable import StallariYRS

@Suite("YAwareness Tests")
struct YAwarenessTests {

    @Test("Create awareness with client ID")
    func create() {
        let aw = YAwareness(clientID: 42)
        #expect(aw.clientCount == 0)
    }

    @Test("Set local state and encode")
    func setLocalAndEncode() throws {
        let aw = YAwareness(clientID: 1)
        let state = #"{"cursor": 10, "user": {"name": "Alice"}}"#.data(using: .utf8)!
        aw.setLocalState(state)

        #expect(aw.clientCount == 1)

        let encoded = try aw.encodeUpdate()
        #expect(encoded.count > 0)
    }

    @Test("Encode and apply awareness roundtrip")
    func roundtrip() throws {
        let aw1 = YAwareness(clientID: 1)
        let state1 = #"{"cursor": 5}"#.data(using: .utf8)!
        aw1.setLocalState(state1)

        let encoded = try aw1.encodeUpdate()

        let aw2 = YAwareness(clientID: 2)
        try aw2.applyUpdate(encoded)

        #expect(aw2.clientCount == 1)

        // Verify the state for client 1 is accessible from aw2
        let retrieved = aw2.clientState(for: 1)
        #expect(retrieved != nil)
        if let data = retrieved {
            let json = String(data: data, encoding: .utf8)
            #expect(json == #"{"cursor": 5}"#)
        }
    }

    @Test("Multiple remote clients")
    func multipleClients() throws {
        let aw1 = YAwareness(clientID: 1)
        aw1.setLocalState(#"{"cursor": 0}"#.data(using: .utf8)!)

        let aw2 = YAwareness(clientID: 2)
        aw2.setLocalState(#"{"cursor": 10}"#.data(using: .utf8)!)

        // Aggregate both into aw3
        let aw3 = YAwareness(clientID: 3)
        try aw3.applyUpdate(try aw1.encodeUpdate())
        try aw3.applyUpdate(try aw2.encodeUpdate())

        #expect(aw3.clientCount == 2)
        #expect(aw3.clientState(for: 1) != nil)
        #expect(aw3.clientState(for: 2) != nil)
    }

    @Test("Unknown client returns nil")
    func unknownClient() {
        let aw = YAwareness(clientID: 1)
        #expect(aw.clientState(for: 999) == nil)
    }

    @Test("Apply invalid update fails gracefully")
    func invalidUpdate() throws {
        let aw = YAwareness(clientID: 1)
        let garbage = Data([0x00, 0x01, 0x02])
        #expect(throws: YRSError.self) {
            try aw.applyUpdate(garbage)
        }
    }
}
