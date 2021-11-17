import XCTest
import Util

protocol RegexCaptureProtocol {
  associatedtype RangeBound: RegexCaptureProtocol
  associatedtype StringBound
  
  func boundToRanges() -> RangeBound
  func bound(in str: String) -> StringBound
  static func recovered(in str: String, from ranges: RangeBound) -> Self
}

extension Range: RegexCaptureProtocol where Bound == String.Index {
  typealias RangeBound = Self
  typealias StringBound = Substring
  
  func boundToRanges() -> Self {
    self
  }
  
  func bound(in str: String) -> Substring {
    str[self]
  }
  
  static func recovered(in str: String, from ranges: RangeBound) -> Self {
    ranges
  }
}

extension Substring: RegexCaptureProtocol {
  typealias RangeBound = Range<String.Index>
  typealias StringBound = Substring
  
  func boundToRanges() -> Range<String.Index> {
    self.startIndex ..< self.endIndex
  }
  
  func bound(in str: String) -> Substring {
    self
  }

  static func recovered(in str: String, from ranges: RangeBound) -> Self {
    str[ranges]
  }
}

extension Optional: RegexCaptureProtocol where Wrapped: RegexCaptureProtocol {
  typealias RangeBound = Wrapped.RangeBound?
  typealias StringBound = Wrapped.StringBound?
  
  func boundToRanges() -> Wrapped.RangeBound? {
    map { $0.boundToRanges() }
  }
  
  func bound(in str: String) -> Wrapped.StringBound? {
    map { $0.bound(in: str) }
  }
  
  static func recovered(in str: String, from ranges: RangeBound) -> Self {
    ranges.map { Wrapped.recovered(in: str, from: $0) }
  }
}

extension Array: RegexCaptureProtocol where Element: RegexCaptureProtocol {
  typealias RangeBound = [Element.RangeBound]
  typealias StringBound = [Element.StringBound]

  func boundToRanges() -> [Element.RangeBound] {
    map { $0.boundToRanges() }
  }
  
  func bound(in str: String) -> [Element.StringBound] {
    map { $0.bound(in: str) }
  }
  
  
  static func recovered(in str: String, from ranges: RangeBound) -> Self {
    ranges.map { Element.recovered(in: str, from: $0) }
  }
}

extension Tuple2: RegexCaptureProtocol where __0: RegexCaptureProtocol, __1: RegexCaptureProtocol {
  typealias RangeBound = Tuple2<__0.RangeBound, __1.RangeBound>
  typealias StringBound = Tuple2<__0.StringBound, __1.StringBound>

  func boundToRanges() -> RangeBound {
    RangeBound(value: (value.0.boundToRanges(), value.1.boundToRanges()))
  }
  
  func bound(in str: String) -> StringBound {
    StringBound(value: (value.0.bound(in: str), value.1.bound(in: str)))
  }
  
  static func recovered(in str: String, from ranges: RangeBound) -> Self {
    .init(value:
      (__0.recovered(in: str, from: ranges._0),
       __1.recovered(in: str, from: ranges._1)
    ))
  }
}

extension Tuple3: RegexCaptureProtocol where __0: RegexCaptureProtocol, __1: RegexCaptureProtocol, __2: RegexCaptureProtocol {
  typealias RangeBound = Tuple3<__0.RangeBound, __1.RangeBound, __2.RangeBound>
  typealias StringBound = Tuple3<__0.StringBound, __1.StringBound, __2.StringBound>

  func boundToRanges() -> RangeBound {
    RangeBound(value: (value.0.boundToRanges(), value.1.boundToRanges(), value.2.boundToRanges()))
  }
  
  func bound(in str: String) -> StringBound {
    StringBound(value: (value.0.bound(in: str), value.1.bound(in: str), value.2.bound(in: str)))
  }
  
  static func recovered(in str: String, from ranges: RangeBound) -> Self {
    .init(value:
      (__0.recovered(in: str, from: ranges._0),
       __1.recovered(in: str, from: ranges._1),
       __2.recovered(in: str, from: ranges._2)
    ))
  }
}

fileprivate struct Regex<Captures: RegexCaptureProtocol> {
  var captureTemplate: Captures
}

@dynamicMemberLookup
fileprivate struct MatchResult<Captures: RegexCaptureProtocol> {
  var _input: String
  var _captureRanges: Captures.RangeBound
  
  init(_input: String, _captureRanges: Captures.RangeBound) {
    self._input = _input
    self._captureRanges = _captureRanges
  }
  
  subscript<T: RegexCaptureProtocol>(dynamicMember path: KeyPath<Captures.RangeBound, T.RangeBound>) -> T {
    T.recovered(in: _input, from: _captureRanges[keyPath: path])
  }
}

class SemanticsTest: XCTestCase {
  func testSemantics() throws {
    // Fake data
    let str = "007F..009F    ; Control # Cc  [33] <control-007F>..<control-009F>"
    // let re = #"(?<lower>[0-9A-F]+)(?:\.\.(?<upper>[0-9A-F]+))?"#

    // Would be: Regex<(Substring, Substring, Substring?)>
    typealias RT = Regex<Tuple3<Substring, Substring, Substring?>>
    let regex = RT(
      captureTemplate: Tuple3(
        value: (str.prefix(10), str.prefix(4), str.dropFirst(6).prefix(4))
      ))
    
    let result = MatchResult<Tuple3<Substring, Substring, Substring?>>(
      _input: str, _captureRanges: regex.captureTemplate.boundToRanges())
//    XCTAssertEqual("007F..009F", result._0)
//    XCTAssertEqual("007F", result._1)
//    XCTAssertEqual("009F", result._2)
  }
}

