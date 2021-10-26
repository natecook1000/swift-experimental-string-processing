import XCTest

// Fake data
let str = "007F..009F    ; Control # Cc  [33] <control-007F>..<control-009F>"

let l1 = str.startIndex
let u1 = str.index(l1, offsetBy: 4)
let r1 = l1..<u1

let l2 = str.index(str.startIndex, offsetBy: 6)
let u2 = str.index(l2, offsetBy: 4)
let r2 = l2..<u2

let ranges = [r1, r2]

// work around no higher-kinded types
protocol RegexCapture {
  associatedtype BoundToString
  associatedtype BoundToUnicodeScalars
  associatedtype BoundToUTF8

  // TODO: Make `ranges` RangesCollection<String.Index>.SubSequence
  // TODO: These should be static functions and `ranges` needs to be more sophisticated so it can drive the Optional and Array cases
  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in string: String
  ) -> BoundToString

  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in unicodeScalars: String.UnicodeScalarView
  ) -> BoundToUnicodeScalars

  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in utf8: String.UTF8View
  ) -> BoundToUTF8
}

protocol StringRegexCapture {
  associatedtype BoundToString
  associatedtype BoundToUTF8
}

// bottom placeholder type
struct Unbound: RegexCapture {
  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in string: String
  ) -> Substring {
    string[ranges.popFirst()!]
  }

  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in unicodeScalars: String.UnicodeScalarView
  ) -> String.UnicodeScalarView.SubSequence {
    unicodeScalars[ranges.popFirst()!]
  }

  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in utf8: String.UTF8View
  ) -> String.UTF8View.SubSequence {
    utf8[ranges.popFirst()!]
  }
}

extension Optional: RegexCapture where Wrapped: RegexCapture {
  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in string: String
  ) -> Wrapped.BoundToString? {
    switch self {
    case let .some(capture):
      return capture.bound(to: &ranges, in: string)
    case .none:
      return Optional<Wrapped.BoundToString>.none
    }
  }

  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in unicodeScalars: String.UnicodeScalarView
  ) -> Wrapped.BoundToUnicodeScalars? {
    switch self {
    case let .some(capture):
      return capture.bound(to: &ranges, in: unicodeScalars)
    case .none:
      return Optional<Wrapped.BoundToUnicodeScalars>.none
    }
  }

  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in utf8: String.UTF8View
  ) -> Wrapped.BoundToUTF8? {
    switch self {
    case let .some(capture):
      return capture.bound(to: &ranges, in: utf8)
    case .none:
      return Optional<Wrapped.BoundToUTF8>.none
    }
  }
}

extension Array: RegexCapture where Element: RegexCapture {
  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in string: String
  ) -> [Element.BoundToString] {
    map { $0.bound(to: &ranges, in: string) }
  }

  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in unicodeScalars: String.UnicodeScalarView
  ) -> [Element.BoundToUnicodeScalars] {
    map { $0.bound(to: &ranges, in: unicodeScalars) }
  }

  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in utf8: String.UTF8View
  ) -> [Element.BoundToUTF8] {
    map { $0.bound(to: &ranges, in: utf8) }
  }
}

struct Pair<First, Second> {
  var first: First
  var second: Second

  init(_ first: First, _ second: Second) {
    self.first = first
    self.second = second
  }
}

extension Pair: Equatable where First: Equatable, Second: Equatable {}

extension Pair: RegexCapture where First: RegexCapture, Second: RegexCapture {
  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in string: String
  ) -> Pair<First.BoundToString, Second.BoundToString> {
    Pair<First.BoundToString, Second.BoundToString>(
      first.bound(to: &ranges, in: string),
      second.bound(to: &ranges, in: string)
    )
  }

  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in unicodeScalars: String.UnicodeScalarView
  ) -> Pair<First.BoundToUnicodeScalars, Second.BoundToUnicodeScalars> {
    Pair<First.BoundToUnicodeScalars, Second.BoundToUnicodeScalars>(
      first.bound(to: &ranges, in: unicodeScalars),
      second.bound(to: &ranges, in: unicodeScalars)
    )
  }

  func bound(
    to ranges: inout ArraySlice<Range<String.Index>>,
    in utf8: String.UTF8View
  ) -> Pair<First.BoundToUTF8, Second.BoundToUTF8> {
    Pair<First.BoundToUTF8, Second.BoundToUTF8>(
      first.bound(to: &ranges, in: utf8),
      second.bound(to: &ranges, in: utf8)
    )
  }
}

protocol MatchResultProtocol {
  associatedtype Captures
  
  var range: Range<String.Index> { get }
  var captures: Captures { get }
}

protocol RegexProtocol {
  associatedtype Captures
  associatedtype MatchResult: MatchResultProtocol
  
  func match(_ string: String) -> MatchResult
}

extension RegexProtocol {
  func map<NewCaptures>(_ transform: @escaping (MatchResult.Captures) -> NewCaptures)
    -> MapRegex<Self, NewCaptures>
  {
    MapRegex(base: self, transform: transform)
  }
}

struct StringRegex<Captures: RegexCapture>: RegexProtocol {
  struct MatchResult: MatchResultProtocol {
    var range: Range<String.Index>
    var captures: Captures.BoundToString
  }
  
  let captures: Captures
  
  func match(_ string: String) -> MatchResult {
    var slice = ranges[...]
    let caps: Captures.BoundToString = captures.bound(to: &slice, in: string)
    return MatchResult(range: l1..<u2, captures: caps)
  }
  
  var posixSemantics: UTF8ViewRegex<Captures> {
    UTF8ViewRegex<Captures>(captures: captures)
  }
}

extension StringRegex.MatchResult: Equatable where Self.Captures: Equatable {}

struct UTF8ViewRegex<Captures: RegexCapture>: RegexProtocol {
  struct MatchResult: MatchResultProtocol {
    var range: Range<String.Index>
    var captures: Captures.BoundToUTF8
  }
  
  let captures: Captures

  func match(_ string: String) -> MatchResult {
    var slice = ranges[...]
    let caps: Captures.BoundToUTF8 = captures.bound(to: &slice, in: string.utf8)
    return MatchResult(range: l1..<u2, captures: caps)
  }
}

extension UTF8ViewRegex.MatchResult: Equatable where Self.Captures: Equatable {}

struct MapRegex<Base: RegexProtocol, Captures>: RegexProtocol {
  struct MatchResult: MatchResultProtocol {
    var range: Range<String.Index>
    var captures: Captures
  }

  let base: Base
  let transform: (Base.MatchResult.Captures) -> Captures
  
  func match(_ string: String) -> MatchResult {
    let result = base.match(string)
    return MatchResult(range: result.range, captures: transform(result.captures))
  }
}

extension MapRegex.MatchResult: Equatable where Self.Captures: Equatable {}

extension String {
  func firstMatch<R: RegexProtocol>(matching regex: R) -> R.MatchResult {
    regex.match(self)
  }

  func allMatches<R: RegexProtocol>(matching regex: R) -> UnfoldFirstSequence<R.MatchResult> {
    sequence(first: regex.match(self), next: { _ in nil })
  }
}

class KyleTests: XCTestCase {
  let regex = StringRegex(captures: Pair(Unbound(), Optional.some(Unbound())))
  
  var utf8Regex: UTF8ViewRegex<Pair<Unbound, Optional<Unbound>>> {
    regex.posixSemantics
  }
  
  var unicodeRangeRegex: MapRegex<StringRegex<Pair<Unbound, Optional<Unbound>>>, Range<Unicode.Scalar>?> {
    regex.map { result -> Range<Unicode.Scalar>? in
      guard
        let lower = UInt32(result.first, radix: 16).flatMap(Unicode.Scalar.init),
        let upper = UInt32(result.second ?? result.first, radix: 16).flatMap(Unicode.Scalar.init)
      else { return nil }
      return lower..<upper
    }
  }

  func testVariant() {
    XCTAssert(type(of: regex.captures) == Pair<Unbound, Optional<Unbound>>.self)
    XCTAssert(type(of: regex).MatchResult.Captures
      == Pair<Substring, Optional<Substring>>.self)
    XCTAssert(type(of: utf8Regex).MatchResult.Captures
      == Pair<String.UTF8View.SubSequence, Optional<String.UTF8View.SubSequence>>.self)
    
    dump(regex.match(str))
    dump(utf8Regex.match(str))
    dump(unicodeRangeRegex.match(str))
  }
  
  func testAPI() throws {
    let regex = StringRegex(captures: Pair(Unbound(), Optional.some(Unbound())))
    let str = str
    
    let strMatch = str.firstMatch(matching: regex)
    XCTAssertEqual(
      StringRegex.MatchResult(
        range: l1..<u2,
        captures: Pair("007F", "009F")),
      strMatch)
    
    let mappedMatch = try XCTUnwrap(str.firstMatch(matching: unicodeRangeRegex))
    XCTAssertEqual(
      MapRegex.MatchResult(
        range: l1..<u2,
        captures: Unicode.Scalar(0x7f)!..<Unicode.Scalar(0x9f)!),
      mappedMatch)
  }
}
