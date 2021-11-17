import XCTest
import Util

protocol RegexCaptureProtocol {
  associatedtype RangeBound: RegexCaptureProtocol
  associatedtype StringBound
  
  func bound(in str: String) -> RangeBound
  func bound(in str: String) -> StringBound
}

extension Range: RegexCaptureProtocol where Bound == String.Index {
  typealias RangeBound = Range<String.Index>
  typealias StringBound = Substring
  
  func bound(in str: String) -> Range<String.Index> {
    return self
  }
  
  func bound(in str: String) -> Substring {
    return str[self]
  }
}

extension Substring: RegexCaptureProtocol {
  typealias RangeBound = Range<String.Index>
  typealias StringBound = Substring
  
  func bound(in str: String) -> Range<String.Index> {
    return self.startIndex ..< self.endIndex
  }
  
  func bound(in str: String) -> Substring {
    return self
  }
}

extension Optional: RegexCaptureProtocol where Wrapped: RegexCaptureProtocol {
  typealias RangeBound = Wrapped.RangeBound?
  typealias StringBound = Wrapped.StringBound?
  
  func bound(in str: String) -> Wrapped.RangeBound? {
    map { $0.bound(in: str) }
  }
  
  func bound(in str: String) -> Wrapped.StringBound? {
    map { $0.bound(in: str) }
  }
}

extension Array: RegexCaptureProtocol where Element: RegexCaptureProtocol {
  typealias RangeBound = [Element.RangeBound]
  typealias StringBound = [Element.StringBound]

  func bound(in str: String) -> [Element.RangeBound] {
    map { $0.bound(in: str) }
  }
  
  func bound(in str: String) -> [Element.StringBound] {
    map { $0.bound(in: str) }
  }
}

extension Tuple2: RegexCaptureProtocol where _0: RegexCaptureProtocol, _1: RegexCaptureProtocol {
  typealias RangeBound = Tuple2<_0.RangeBound, _1.RangeBound>
  typealias StringBound = Tuple2<_0.StringBound, _1.StringBound>

  func bound(in str: String) -> RangeBound {
    RangeBound(value: (value.0.bound(in: str), value.1.bound(in: str)))
  }
  
  func bound(in str: String) -> StringBound {
    StringBound(value: (value.0.bound(in: str), value.1.bound(in: str)))
  }
}

extension Tuple3: RegexCaptureProtocol where _0: RegexCaptureProtocol, _1: RegexCaptureProtocol, _2: RegexCaptureProtocol {
  typealias RangeBound = Tuple3<_0.RangeBound, _1.RangeBound, _2.RangeBound>
  typealias StringBound = Tuple3<_0.StringBound, _1.StringBound, _2.StringBound>

  func bound(in str: String) -> RangeBound {
    RangeBound(value: (value.0.bound(in: str), value.1.bound(in: str), value.2.bound(in: str)))
  }
  
  func bound(in str: String) -> StringBound {
    StringBound(value: (value.0.bound(in: str), value.1.bound(in: str), value.2.bound(in: str)))
  }
}

fileprivate struct Regex<Captures: RegexCaptureProtocol> {
  var captureTemplate: Captures
}

@dynamicMemberLookup
fileprivate struct MatchResult<Captures: RegexCaptureProtocol> {
  var _input: String
  var _captures: Captures
  
  init(_input: String, _captures: Captures) {
    self._input = _input
    self._captures = _captures
  }
  
  var ranges: Captures.RangeBound {
    _captures.bound(in: _input)
  }
  var captures: Captures.StringBound {
    _captures.bound(in: _input)
  }
  
  subscript<T>(dynamicMember path: KeyPath<Captures.StringBound, T>) -> T {
    captures[keyPath: path]
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
    
    let result = MatchResult(_input: str, _captures: regex.captureTemplate)
    XCTAssertEqual("007F..009F", result._0)
    XCTAssertEqual("007F", result._1)
    XCTAssertEqual("009F", result._2)
  }
}

