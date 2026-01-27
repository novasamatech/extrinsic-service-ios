import Testing
import Foundation
import SubstrateSdk
@testable import ExtrinsicService

@Suite("Message Timestamp Formatter Tests")
final class ExtrinsicStatusParsingTests {
    @Test func canParseFuture() async throws {
        let json = """
            {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"UusXUmjhaJfiNoT7","result":"future"}}
        """
        
        let status = try decode(json)
        
        #expect(status == .future)
    }
    
    @Test func canParseReady() async throws {
        let json = """
            {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"UusXUmjhaJfiNoT7","result":"ready"}}
        """
        
        let status = try decode(json)
        
        #expect(status == .ready)
    }

    @Test func canParseBroadcast() async throws {
        let json = """
            {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"UusXUmjhaJfiNoT7","result":{"broadcast":["12D3KooWLQnyB8575EufygjEiwYPyyBcYYZYGPSFuKz9qSDVvEda","12D3KooWFHmaT5ct93DBLUqRZviDtPD3659rQqwxocjUT6Jqx3xA"]}}}
        """
        
        let status = try decode(json)
        
        #expect(status == .broadcast(["12D3KooWLQnyB8575EufygjEiwYPyyBcYYZYGPSFuKz9qSDVvEda", "12D3KooWFHmaT5ct93DBLUqRZviDtPD3659rQqwxocjUT6Jqx3xA"]))
    }

    @Test func canParseInBlock() async throws {
        let json = """
            {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"UusXUmjhaJfiNoT7","result":{"inBlock":"0x69d25c4f2cfd1eeae88455679f435569024f2e723a403062929e3d4557a531b7"}}}
        """
        
        let status = try decode(json)
        
        #expect(status == .inBlock("0x69d25c4f2cfd1eeae88455679f435569024f2e723a403062929e3d4557a531b7"))
    }
    
    @Test func canParseFinalized() async throws {
        let json = """
            {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"UusXUmjhaJfiNoT7","result":{"finalized":"0x69d25c4f2cfd1eeae88455679f435569024f2e723a403062929e3d4557a531b7"}}}
        """
        
        let status = try decode(json)
        
        #expect(status == .finalized("0x69d25c4f2cfd1eeae88455679f435569024f2e723a403062929e3d4557a531b7"))
    }
    
    @Test func canParseFinalityTimeout() async throws {
        let json = """
            {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"UusXUmjhaJfiNoT7","result":{"finalityTimeout":"0x69d25c4f2cfd1eeae88455679f435569024f2e723a403062929e3d4557a531b7"}}}
        """
        
        let status = try decode(json)
        
        #expect(status == .finalityTimeout("0x69d25c4f2cfd1eeae88455679f435569024f2e723a403062929e3d4557a531b7"))
    }
    
    @Test func canParseInvalid() async throws {
        let json = """
            {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"UusXUmjhaJfiNoT7","result": "invalid"}}
        """
        
        let status = try decode(json)
        
        #expect(status == .invalid)
    }
    
    @Test func canParseDropped() async throws {
        let json = """
            {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"UusXUmjhaJfiNoT7","result": "dropped"}}
        """
        
        let status = try decode(json)
        
        #expect(status == .dropped)
    }
    
    @Test func canParseOther() async throws {
        let json = """
            {"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"UusXUmjhaJfiNoT7","result": "someNew"}}
        """
        
        let status = try decode(json)
        
        #expect(status == .other)
    }
}

private extension ExtrinsicStatusParsingTests {
    func decode(_ json: String) throws -> ExtrinsicStatus {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(
            JSONRPCSubscriptionUpdate<ExtrinsicStatus>.self,
            from: data
        )
        return msg.params.result
    }
}
