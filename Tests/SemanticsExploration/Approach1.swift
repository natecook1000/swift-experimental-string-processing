import XCTest

enum Capture {
  case subrange(Range<String.Index>)
  indirect case tuple([Capture])
  indirect case optional(Capture?)
  indirect case array([Capture])
}

// work around no higher-kinded types
fileprivate protocol RegexMatch {
  associatedtype BoundToRange
  associatedtype BoundToString
  associatedtype BoundToUnicodeScalars
  associatedtype BoundToUTF8

  static func bound(
    to capture: Capture
  ) -> BoundToRange

  static func bound(
    to capture: Capture,
    in string: String
  ) -> BoundToString

  static func bound(
    to capture: Capture,
    in unicodeScalars: String.UnicodeScalarView
  ) -> BoundToUnicodeScalars

  static func bound(
    to capture: Capture,
    in utf8: String.UTF8View
  ) -> BoundToUTF8
}

// bottom placeholder type
struct Unbound: RegexMatch {
  static func bound(
    to capture: Capture
  ) -> Range<String.Index> {
    guard case let .subrange(range) = capture else {
      fatalError()
    }
    return range
  }

  static func bound(
    to capture: Capture,
    in string: String
  ) -> Substring {
    return string[bound(to: capture)]
  }

  static func bound(
    to capture: Capture,
    in unicodeScalars: String.UnicodeScalarView
  ) -> String.UnicodeScalarView.SubSequence {
    return unicodeScalars[bound(to: capture)]
  }

  static func bound(
    to capture: Capture,
    in utf8: String.UTF8View
  ) -> String.UTF8View.SubSequence {
    return utf8[bound(to: capture)]
  }
}

extension Optional: RegexMatch where Wrapped: RegexMatch {
  static func bound(
    to capture: Capture
  ) -> Wrapped.BoundToRange? {
    guard case let .optional(capture) = capture else {
      fatalError()
    }
    return capture.map { Wrapped.bound(to: $0) }
  }

  static func bound(
    to capture: Capture,
    in string: String
  ) -> Wrapped.BoundToString? {
    guard case let .optional(capture) = capture else {
      fatalError()
    }
    return capture.map { Wrapped.bound(to: $0, in: string) }
  }

  static func bound(
    to capture: Capture,
    in unicodeScalars: String.UnicodeScalarView
  ) -> Wrapped.BoundToUnicodeScalars? {
    guard case let .optional(capture) = capture else {
      fatalError()
    }
    return capture.map { Wrapped.bound(to: $0, in: unicodeScalars) }
  }

  static func bound(
    to capture: Capture,
    in utf8: String.UTF8View
  ) -> Wrapped.BoundToUTF8? {
    guard case let .optional(capture) = capture else {
      fatalError()
    }
    return capture.map { Wrapped.bound(to: $0, in: utf8) }
  }
}

extension Array: RegexMatch where Element: RegexMatch {
  static func bound(
    to capture: Capture
  ) -> [Element.BoundToRange] {
    guard case let .array(captures) = capture else {
      fatalError()
    }
    return captures.map { Element.bound(to: $0) }
  }

  static func bound(
    to capture: Capture,
    in string: String
  ) -> [Element.BoundToString] {
    guard case let .array(captures) = capture else {
      fatalError()
    }
    return captures.map { Element.bound(to: $0, in: string) }
  }

  static func bound(
    to capture: Capture,
    in unicodeScalars: String.UnicodeScalarView
  ) -> [Element.BoundToUnicodeScalars] {
    guard case let .array(captures) = capture else {
      fatalError()
    }
    return captures.map { Element.bound(to: $0, in: unicodeScalars) }
  }

  static func bound(
    to capture: Capture,
    in utf8: String.UTF8View
  ) -> [Element.BoundToUTF8] {
    guard case let .array(captures) = capture else {
      fatalError()
    }
    return captures.map { Element.bound(to: $0, in: utf8) }
  }
}

extension Tuple3: RegexMatch where __0: RegexMatch, __1: RegexMatch, __2: RegexMatch {
  static func bound(
    to capture: Capture
  ) -> Tuple3<__0.BoundToRange, __1.BoundToRange, __2.BoundToRange> {
    guard case let .tuple(captures) = capture else {
      fatalError()
    }
    return Tuple3<__0.BoundToRange, __1.BoundToRange, __2.BoundToRange>(value: (
      __0.bound(to: captures[0]),
      __1.bound(to: captures[1]),
      __2.bound(to: captures[2])
    ))
  }

  static func bound(
    to capture: Capture,
    in string: String
  ) -> Tuple3<__0.BoundToString, __1.BoundToString, __2.BoundToString> {
    guard case let .tuple(captures) = capture else {
      fatalError()
    }
    return Tuple3<__0.BoundToString, __1.BoundToString, __2.BoundToString>(value: (
      __0.bound(to: captures[0], in: string),
      __1.bound(to: captures[1], in: string),
      __2.bound(to: captures[2], in: string)
    ))
  }

  static func bound(
    to capture: Capture,
    in unicodeScalars: String.UnicodeScalarView
  ) -> Tuple3<__0.BoundToUnicodeScalars, __1.BoundToUnicodeScalars, __2.BoundToUnicodeScalars> {
    guard case let .tuple(captures) = capture else {
      fatalError()
    }
    return Tuple3<__0.BoundToUnicodeScalars, __1.BoundToUnicodeScalars, __2.BoundToUnicodeScalars>(value: (
      __0.bound(to: captures[0], in: unicodeScalars),
      __1.bound(to: captures[1], in: unicodeScalars),
      __2.bound(to: captures[2], in: unicodeScalars)
    ))
  }

  static func bound(
    to capture: Capture,
    in utf8: String.UTF8View
  ) -> Tuple3<__0.BoundToUTF8, __1.BoundToUTF8, __2.BoundToUTF8> {
    guard case let .tuple(captures) = capture else {
      fatalError()
    }
    return Tuple3<__0.BoundToUTF8, __1.BoundToUTF8, __2.BoundToUTF8>(value: (
      __0.bound(to: captures[0], in: utf8),
      __1.bound(to: captures[1], in: utf8),
      __2.bound(to: captures[2], in: utf8)
    ))
  }
}

fileprivate struct Regex<Match: RegexMatch> {
  let match: Capture
}

extension String {
  fileprivate func firstMatch<Match>(of regex: Regex<Match>) -> Match.BoundToString? {
    return Match.bound(to: regex.match, in: self)
  }
}

class SemanticsApproach1Test: XCTestCase {
  func testSemantics() throws {
    // Fake data
    let str = "007F..009F    ; Control # Cc  [33] <control-007F>..<control-009F>"
    // let re = #"(?<lower>[0-9A-F]+)(?:\.\.(?<upper>[0-9A-F]+))?"#

    let l1 = str.startIndex
    let u1 = str.index(l1, offsetBy: 4)
    let r1 = l1..<u1

    let l2 = str.index(str.startIndex, offsetBy: 6)
    let u2 = str.index(l2, offsetBy: 4)
    let r2 = l2..<u2

    let r0 = l1..<u2

    let regex = Regex<Tuple3<Unbound, Unbound, Unbound?>>(
      match: .tuple([.subrange(r0), .subrange(r1), .optional(.subrange(r2))]))

    let result = str.firstMatch(of: regex)
    XCTAssertEqual(result?._0, "007F..009F")
    XCTAssertEqual(result?._1, "007F")
    XCTAssertEqual(result?._2, "009F")
  }
}
