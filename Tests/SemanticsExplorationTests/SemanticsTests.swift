import XCTest
import Util
import SemanticsExploration

class SemanticsTests: XCTestCase {
  let str = "007F..009F    ; Control # Cc  [33] <control-007F>..<control-009F>"
  // let regex = /(?<lower>[0-9A-F]+)(?:\.\.(?<upper>[0-9A-F]+))?/

  lazy var expectedRanges = (
    str.index(atOffset: 0)..<str.index(atOffset: 10),
    str.index(atOffset: 0)..<str.index(atOffset: 4),
    str.index(atOffset: 6)..<str.index(atOffset: 10)
  )
  
  fileprivate var regex: Regex<Tuple3<Submatch, Submatch, Submatch?>> {
    let l1 = str.startIndex
    let u1 = str.index(l1, offsetBy: 4)
    let r1 = l1..<u1

    let l2 = str.index(str.startIndex, offsetBy: 6)
    let u2 = str.index(l2, offsetBy: 4)
    let r2 = l2..<u2

    let r0 = l1..<u2
    return .init(
      _match: .tuple([.range(r0), .range(r1), .optional(.range(r2))]))
  }
  
  func testString() throws {
    let result = try XCTUnwrap(str.firstMatch(of: regex))
    XCTAssertEqual(result.fullMatch, result._0)
    XCTAssertEqual("007F..009F", result._0)  // 007F..009F
    XCTAssertEqual("007F", result._1)        // 007F
    XCTAssertEqual("009F", result._2!)       // 009F

    // We can elide `.value` when tuples conform to `RegexMatch`
    XCTAssert(result.allCaptures.value == ("007F..009F", "007F", "009F"))
    
    let ranges = result.ranges
    XCTAssertEqual(expectedRanges.0, ranges._0)
    XCTAssertEqual(expectedRanges.1, ranges._1)
    XCTAssertEqual(expectedRanges.2, ranges._2)
  }

  func testUTF8Semantics() throws {
    let uft8Regex = regex.utf8Semantics

    let result = try XCTUnwrap(str.firstMatch(of: uft8Regex))
    XCTAssert(result.fullMatch.elementsEqual(result._0))
    XCTAssertEqual(expectedRanges.0, result.fullRange)
    XCTAssert("007F..009F".utf8.elementsEqual(result._0))  // 007F..009F
    XCTAssert("007F".utf8.elementsEqual(result._1))        // 007F
    XCTAssert("009F".utf8.elementsEqual(result._2!))       // 009F

    let ranges = result.ranges
    XCTAssertEqual(expectedRanges.0, ranges._0)
    XCTAssertEqual(expectedRanges.1, ranges._1)
    XCTAssertEqual(expectedRanges.2, ranges._2)
  }
  
  func testMap() throws {
    let rangeRegex = regex.mapCaptures { captures -> ClosedRange<UInt32> in
      let lower = UInt32(captures._1, radix: 16)!
      let upper = captures._2.map { UInt32($0, radix: 16)! } ?? lower
      return lower...upper
    }
    let result = try XCTUnwrap(str.firstMatch(of: rangeRegex))
    XCTAssertEqual(0x007F...0x009F, result)
  }
}
