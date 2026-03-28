import XCTest
@testable import RemindMe

final class ParserTests: XCTestCase {
    
    let mockDate = Date(timeIntervalSince1970: 1000000)
    
    func parse(_ input: String) -> Result<(title: String, firesAt: Date), ParseError> {
        return ReminderParser.parse(input, now: { self.mockDate })
    }
    
    func testBasicMinutesToken() {
        let result = parse("deploy fix @10m")
        guard case .success(let payload) = result else { return XCTFail() }
        XCTAssertEqual(payload.title, "deploy fix")
        XCTAssertEqual(payload.firesAt, mockDate.addingTimeInterval(600))
    }
    
    func testBasicHoursToken() {
        let result = parse("deploy fix @2h")
        guard case .success(let payload) = result else { return XCTFail() }
        XCTAssertEqual(payload.title, "deploy fix")
        XCTAssertEqual(payload.firesAt, mockDate.addingTimeInterval(7200))
    }
    
    func testCompoundToken() {
        let result = parse("run tests @1h30m")
        guard case .success(let payload) = result else { return XCTFail() }
        XCTAssertEqual(payload.title, "run tests")
        XCTAssertEqual(payload.firesAt, mockDate.addingTimeInterval(5400))
    }
    
    func testSecondsToken() {
        let result = parse("quick check @30s")
        guard case .success(let payload) = result else { return XCTFail() }
        XCTAssertEqual(payload.title, "quick check")
        XCTAssertEqual(payload.firesAt, mockDate.addingTimeInterval(30))
    }
    
    func testTokenAtBeginning() {
        let result = parse("@2h check build")
        guard case .success(let payload) = result else { return XCTFail() }
        XCTAssertEqual(payload.title, "check build")
        XCTAssertEqual(payload.firesAt, mockDate.addingTimeInterval(7200))
    }
    
    func testTokenInMiddle() {
        let result = parse("call mom @10m about dinner")
        guard case .success(let payload) = result else { return XCTFail() }
        XCTAssertEqual(payload.title, "call mom about dinner")
        XCTAssertEqual(payload.firesAt, mockDate.addingTimeInterval(600))
    }
    
    func testNoTokenDefaultsTo10Minutes() {
        let result = parse("review PR")
        guard case .success(let payload) = result else { return XCTFail() }
        XCTAssertEqual(payload.title, "review PR")
        XCTAssertEqual(payload.firesAt, mockDate.addingTimeInterval(600))
    }
    
    func testInvalidTokenReturnsError() {
        let result = parse("test task @xyz")
        guard case .failure(let error) = result else { return XCTFail() }
        XCTAssertEqual(error, .invalidToken)
    }
    
    func testNoTitleReturnsError() {
        let result = parse("@5m")
        guard case .failure(let error) = result else { return XCTFail() }
        XCTAssertEqual(error, .noTitle)
    }
    
    func testEmptyStringReturnsError() {
        let result = parse("")
        guard case .failure(let error) = result else { return XCTFail() }
        XCTAssertEqual(error, .noTitle)
    }
    
    func testMultipleTokensUsesFirstValid() {
        let result = parse("Ping @john @10m")
        guard case .success(let payload) = result else { return XCTFail() }
        XCTAssertEqual(payload.title, "Ping @john")
        XCTAssertEqual(payload.firesAt, mockDate.addingTimeInterval(600))
    }
    
    func testWhitespaceTrimming() {
        let result = parse("   check logs    @1h  ")
        guard case .success(let payload) = result else { return XCTFail() }
        XCTAssertEqual(payload.title, "check logs")
        XCTAssertEqual(payload.firesAt, mockDate.addingTimeInterval(3600))
    }
    
    func testTitleWithNumbers() {
        let result = parse("deploy v2.3 @10m")
        guard case .success(let payload) = result else { return XCTFail() }
        XCTAssertEqual(payload.title, "deploy v2.3")
    }
}
