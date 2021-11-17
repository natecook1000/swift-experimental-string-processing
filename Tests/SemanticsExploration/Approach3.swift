import XCTest
import Util

fileprivate enum AnyRegexMatch {
  case range(Range<String.Index>)
  indirect case tuple([AnyRegexMatch])
  indirect case optional(AnyRegexMatch?)
  indirect case array([AnyRegexMatch])
}

// work around no higher-kinded types
fileprivate protocol RegexMatch {
  associatedtype BoundToRange
  associatedtype BoundToString
  associatedtype BoundToUTF8View

  init(_ match: AnyRegexMatch)

  func boundToRange() -> BoundToRange
  func bound(to string: String) -> BoundToString
  func bound(to utf8View: String.UTF8View) -> BoundToUTF8View
}

// bottom placeholder type
fileprivate struct Submatch: RegexMatch {
  let range: Range<String.Index>

  init(_ match: AnyRegexMatch) {
    guard case let .range(r) = match else {
      fatalError()
    }
    range = r
  }

  func boundToRange() -> Range<String.Index> {
    range
  }

  func bound(to string: String) -> Substring {
    string[range]
  }

  func bound(to utf8View: String.UTF8View)
    -> String.UTF8View.SubSequence
  {
    utf8View[range]
  }
}

extension Optional: RegexMatch where Wrapped: RegexMatch {
  init(_ match: AnyRegexMatch) {
    guard case let .optional(submatch) = match else {
      fatalError()
    }

    self = submatch.map { Wrapped($0) }
  }

  func boundToRange() -> Wrapped.BoundToRange? {
    map { $0.boundToRange() }
  }

  func bound(to string: String) -> Wrapped.BoundToString? {
    map { $0.bound(to: string) }
  }

  func bound(to utf8View: String.UTF8View) -> Wrapped.BoundToUTF8View? {
    map { $0.bound(to: utf8View) }
  }
}

extension Array: RegexMatch where Element: RegexMatch {
  init(_ match: AnyRegexMatch) {
    guard case let .array(submatches) = match else {
      fatalError()
    }

    self = submatches.map { Element($0) }
  }

  func boundToRange() -> [Element.BoundToRange] {
    map { $0.boundToRange() }
  }

  func bound(to string: String) -> [Element.BoundToString] {
    map { $0.bound(to: string) }
  }

  func bound(to utf8View: String.UTF8View) -> [Element.BoundToUTF8View] {
    map { $0.bound(to: utf8View) }
  }
}

extension Tuple3: RegexMatch where __0: RegexMatch, __1: RegexMatch, __2: RegexMatch {
  init(_ match: AnyRegexMatch) {
    guard case let .tuple(submatches) = match else {
      fatalError()
    }

    self = .init(
      _0: __0(submatches[0]),
      _1: __1(submatches[1]),
      _2: __2(submatches[2])
    )
  }

  func boundToRange()
    -> Tuple3<__0.BoundToRange, __1.BoundToRange, __2.BoundToRange>
  {
    .init(
      _0: _0.boundToRange(),
      _1: _1.boundToRange(),
      _2: _2.boundToRange()
    )
  }

  func bound(to string: String)
    -> Tuple3<__0.BoundToString, __1.BoundToString, __2.BoundToString>
  {
    .init(
      _0: _0.bound(to: string),
      _1: _1.bound(to: string),
      _2: _2.bound(to: string)
    )
  }

  func bound(to utf8View: String.UTF8View)
    -> Tuple3<__0.BoundToUTF8View, __1.BoundToUTF8View, __2.BoundToUTF8View>
  {
    .init(
      _0: _0.bound(to: utf8View),
      _1: _1.bound(to: utf8View),
      _2: _2.bound(to: utf8View)
    )
  }
}

fileprivate protocol RegexProtocol {
  associatedtype Match
  associatedtype MatchResult: RegexMatchResultProtocol
    where MatchResult.Match == Match
  
  init(_match: AnyRegexMatch)
  var _match: AnyRegexMatch { get }
}

fileprivate protocol RegexMatchResultProtocol {
  associatedtype Match: RegexMatch

  init(_string: String, _match: AnyRegexMatch)
}

fileprivate struct Regex<Match: RegexMatch>: RegexProtocol {
  let _match: AnyRegexMatch
  
  @dynamicMemberLookup
  fileprivate struct MatchResult: RegexMatchResultProtocol {
    let _string: String
    let _match: Match

    init(_string: String, _match: AnyRegexMatch) {
      self._string = _string
      self._match = Match(_match)
    }

    subscript<T: RegexMatch>(dynamicMember keyPath: KeyPath<Match, T>) -> T.BoundToString {
      _match[keyPath: keyPath].bound(to: _string)
    }

    @dynamicMemberLookup
    struct Ranges {
      let _match: Match

      subscript<T: RegexMatch>(dynamicMember keyPath: KeyPath<Match, T>) -> T.BoundToRange {
        _match[keyPath: keyPath].boundToRange()
      }
    }

    var ranges: Ranges {
      Ranges(_match: _match)
    }
  }
}

fileprivate struct UTF8Regex<Match: RegexMatch>: RegexProtocol {
  let _match: AnyRegexMatch
  
  @dynamicMemberLookup
  fileprivate struct MatchResult: RegexMatchResultProtocol {
    let _string: String
    let _match: Match

    init(_string: String, _match: AnyRegexMatch) {
      self._string = _string
      self._match = Match(_match)
    }

    subscript<T: RegexMatch>(dynamicMember keyPath: KeyPath<Match, T>) -> T.BoundToUTF8View {
      _match[keyPath: keyPath].bound(to: _string.utf8)
    }

    @dynamicMemberLookup
    struct Ranges {
      let _match: Match

      subscript<T: RegexMatch>(dynamicMember keyPath: KeyPath<Match, T>) -> T.BoundToRange {
        _match[keyPath: keyPath].boundToRange()
      }
    }

    var ranges: Ranges {
      Ranges(_match: _match)
    }
  }
}

extension RegexProtocol {
  var utf8Semantics: UTF8Regex<Match> {
    UTF8Regex(_match: _match)
  }
  
  var unicodeSemantics: Regex<Match> {
    Regex(_match: _match)
  }
}

extension String {
  fileprivate func firstMatch<R: RegexProtocol>(of regex: R) -> R.MatchResult? {
    return R.MatchResult(_string: self, _match: regex._match)
  }
}

class Approach3Tests: XCTestCase {
  let str = "007F..009F    ; Control # Cc  [33] <control-007F>..<control-009F>"
  // let regex = /(?<lower>[0-9A-F]+)(?:\.\.(?<upper>[0-9A-F]+))?/

  lazy var expectedRanges = (
    str.index(atOffset: 0)..<str.index(atOffset: 10),
    str.index(atOffset: 0)..<str.index(atOffset: 4),
    str.index(atOffset: 6)..<str.index(atOffset: 10)
  )
  
  func testString() throws {
    let l1 = str.startIndex
    let u1 = str.index(l1, offsetBy: 4)
    let r1 = l1..<u1

    let l2 = str.index(str.startIndex, offsetBy: 6)
    let u2 = str.index(l2, offsetBy: 4)
    let r2 = l2..<u2

    let r0 = l1..<u2

    let regex = Regex<Tuple3<Submatch, Submatch, Submatch?>>(
      _match: .tuple([.range(r0), .range(r1), .optional(.range(r2))]))

    let result = try XCTUnwrap(str.firstMatch(of: regex))
    print(type(of: result)) // MatchResult<Tuple3<Submatch, Submatch, Optional<Submatch>>>
    XCTAssertEqual("007F..009F", result._0)  // 007F..009F
    XCTAssertEqual("007F", result._1)        // 007F
    XCTAssertEqual("009F", result._2!)       // 009F

    let ranges = result.ranges
    XCTAssertEqual(expectedRanges.0, ranges._0)
    XCTAssertEqual(expectedRanges.1, ranges._1)
    XCTAssertEqual(expectedRanges.2, ranges._2)
  }

  func testUTF8Semantics() throws {
    let l1 = str.unicodeScalars.startIndex
    let u1 = str.unicodeScalars.index(l1, offsetBy: 4)
    let r1 = l1..<u1

    let l2 = str.unicodeScalars.index(str.startIndex, offsetBy: 6)
    let u2 = str.unicodeScalars.index(l2, offsetBy: 4)
    let r2 = l2..<u2

    let r0 = l1..<u2

    let regex = Regex<Tuple3<Submatch, Submatch, Submatch?>>(
      _match: .tuple([.range(r0), .range(r1), .optional(.range(r2))]))
      .utf8Semantics

    let result = try XCTUnwrap(str.firstMatch(of: regex))
    print(type(of: result)) // MatchResult<Tuple3<Submatch, Submatch, Optional<Submatch>>>
    XCTAssert("007F..009F".utf8.elementsEqual(result._0))  // 007F..009F
    XCTAssert("007F".utf8.elementsEqual(result._1))        // 007F
    XCTAssert("009F".utf8.elementsEqual(result._2!))       // 009F

    let ranges = result.ranges
    XCTAssertEqual(expectedRanges.0, ranges._0)
    XCTAssertEqual(expectedRanges.1, ranges._1)
    XCTAssertEqual(expectedRanges.2, ranges._2)
  }
}
