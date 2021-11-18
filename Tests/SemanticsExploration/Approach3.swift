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

  associatedtype InitialMember: RegexMatch
  
  init(_ match: AnyRegexMatch)

  var initialMember: InitialMember { get }
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

  var initialMember: Submatch {
    self
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

  var initialMember: Self {
    self
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

  var initialMember: Element? {
    first
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

  var initialMember: __0 {
    self._0
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

fileprivate protocol PatternProtocol {
  associatedtype Match: RegexMatch
  associatedtype MatchResult
  
  init(_match: AnyRegexMatch)
  var _match: AnyRegexMatch { get }
  func _getMatchResult(for str: String) -> MatchResult
}

fileprivate protocol RegexMatchResultProtocol {
  associatedtype Match: RegexMatch
  associatedtype AllCaptures
  associatedtype FullMatch
  
  // A destructured version of the captures, bound to the correct type.
  var allCaptures: AllCaptures { get }
  
  // The entire matched substring, bound to the correct type.
  var fullMatch: FullMatch { get }
  
  // The entire matched range.
  var fullRange: Match.InitialMember.BoundToRange { get }
}

fileprivate struct Regex<Match: RegexMatch>: PatternProtocol {
  let _match: AnyRegexMatch
  
  func _getMatchResult(for str: String) -> MatchResult {
    MatchResult(_string: str, _match: _match)
  }
  
  @dynamicMemberLookup
  fileprivate struct MatchResult: RegexMatchResultProtocol {
    let _string: String
    let _match: Match

    init(_string: String, _match: AnyRegexMatch) {
      self._string = _string
      self._match = Match(_match)
    }
    
    var fullMatch: Match.InitialMember.BoundToString {
      _match.initialMember.bound(to: _string)
    }
    
    var fullRange: Match.InitialMember.BoundToRange {
      _match.initialMember.boundToRange()
    }
    
    var allCaptures: Match.BoundToString {
      _match.bound(to: _string)
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

fileprivate struct UTF8Regex<Match: RegexMatch>: PatternProtocol {
  let _match: AnyRegexMatch
  
  func _getMatchResult(for str: String) -> MatchResult {
    MatchResult(_string: str, _match: _match)
  }
  
  @dynamicMemberLookup
  fileprivate struct MatchResult: RegexMatchResultProtocol {
    let _string: String
    let _match: Match

    init(_string: String, _match: AnyRegexMatch) {
      self._string = _string
      self._match = Match(_match)
    }
    
    var fullMatch: Match.InitialMember.BoundToUTF8View {
      _match.initialMember.bound(to: _string.utf8)
    }
    
    var fullRange: Match.InitialMember.BoundToRange {
      _match.initialMember.boundToRange()
    }
    
    var allCaptures: Match.BoundToUTF8View {
      _match.bound(to: _string.utf8)
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

extension PatternProtocol where MatchResult: RegexMatchResultProtocol {
  var utf8Semantics: UTF8Regex<Match> {
    UTF8Regex(_match: _match)
  }
  
  var unicodeSemantics: Regex<Match> {
    Regex(_match: _match)
  }
  
  func mapCaptures<T>(_ transform: @escaping (MatchResult.AllCaptures) -> T)
    -> RegexMap<Self, T> {
    RegexMap(regex: self, transform: transform)
  }
}

fileprivate struct RegexMap<R: PatternProtocol, T>
  where R.MatchResult: RegexMatchResultProtocol
{
  var regex: R
  var transform: (R.MatchResult.AllCaptures) -> T
}

extension RegexMap: PatternProtocol {
  init(_match: AnyRegexMatch) {
    fatalError()
  }
  var _match: AnyRegexMatch { fatalError() }
  
  func _getMatchResult(for str: String) -> T {
    transform(regex._getMatchResult(for: str).allCaptures)
  }
  
  typealias Match = R.Match
}

extension String {
  fileprivate func firstMatch<R: PatternProtocol>(of regex: R) -> R.MatchResult? {
    return regex._getMatchResult(for: self)
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
    print(type(of: result)) // MatchResult<Tuple3<Submatch, Submatch, Optional<Submatch>>>
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
    print(type(of: result)) // MatchResult<Tuple3<Submatch, Submatch, Optional<Submatch>>>
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
