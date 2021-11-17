import XCTest

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
  associatedtype BoundToUnicodeScalars

  init(_ match: AnyRegexMatch)

  func boundToRange() -> BoundToRange
  func bound(to string: String) -> BoundToString
  func bound(to unicodeScalars: String.UnicodeScalarView) -> BoundToUnicodeScalars
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

  func bound(to unicodeScalars: String.UnicodeScalarView)
    -> String.UnicodeScalarView.SubSequence
  {
    unicodeScalars[range]
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

  func bound(to unicodeScalars: String.UnicodeScalarView) -> Wrapped.BoundToUnicodeScalars? {
    map { $0.bound(to: unicodeScalars) }
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

  func bound(to unicodeScalars: String.UnicodeScalarView) -> [Element.BoundToUnicodeScalars] {
    map { $0.bound(to: unicodeScalars) }
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

  func bound(to unicodeScalars: String.UnicodeScalarView)
    -> Tuple3<__0.BoundToUnicodeScalars, __1.BoundToUnicodeScalars, __2.BoundToUnicodeScalars>
  {
    .init(
      _0: _0.bound(to: unicodeScalars),
      _1: _1.bound(to: unicodeScalars),
      _2: _2.bound(to: unicodeScalars)
    )
  }
}

fileprivate struct Regex<Match: RegexMatch> {
  let _match: AnyRegexMatch
}

extension String {
  @dynamicMemberLookup
  fileprivate struct MatchResult<Match: RegexMatch> {
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

  fileprivate func firstMatch<Match>(of regex: Regex<Match>) -> MatchResult<Match>? {
    return MatchResult(_string: self, _match: regex._match)
  }
}


extension String.UnicodeScalarView {
  @dynamicMemberLookup
  fileprivate struct MatchResult<Match: RegexMatch> {
    let _unicodeScalars: String.UnicodeScalarView
    let _match: Match

    init(_unicodeScalars: String.UnicodeScalarView, _match: AnyRegexMatch) {
      self._unicodeScalars = _unicodeScalars
      self._match = Match(_match)
    }

    subscript<T: RegexMatch>(
      dynamicMember keyPath: KeyPath<Match, T>
    ) -> T.BoundToUnicodeScalars {
      _match[keyPath: keyPath].bound(to: _unicodeScalars)
    }

    @dynamicMemberLookup
    struct Ranges {
      let _match: Match

      subscript<T: RegexMatch>(
        dynamicMember keyPath: KeyPath<Match, T>
      ) -> T.BoundToRange {
        _match[keyPath: keyPath].boundToRange()
      }
    }

    var ranges: Ranges {
      Ranges(_match: _match)
    }
  }

  fileprivate func firstMatch<Match>(of regex: Regex<Match>) -> MatchResult<Match>? {
    return MatchResult(_unicodeScalars: self, _match: regex._match)
  }
}

class Approach2Tests: XCTestCase {
  func testString() {
    // let regex = /(?<lower>[0-9A-F]+)(?:\.\.(?<upper>[0-9A-F]+))?/
    let str = "007F..009F    ; Control # Cc  [33] <control-007F>..<control-009F>"

    let l1 = str.startIndex
    let u1 = str.index(l1, offsetBy: 4)
    let r1 = l1..<u1

    let l2 = str.index(str.startIndex, offsetBy: 6)
    let u2 = str.index(l2, offsetBy: 4)
    let r2 = l2..<u2

    let r0 = l1..<u2

    let regex = Regex<Tuple3<Submatch, Submatch, Submatch?>>(
      _match: .tuple([.range(r0), .range(r1), .optional(.range(r2))]))

    if let result = str.firstMatch(of: regex) {
      print(type(of: result)) // MatchResult<Tuple3<Submatch, Submatch, Optional<Submatch>>>
      print(result._0)        // 007F..009F
      print(result._1)        // 007F
      print(result._2!)       // 009F

      let ranges = result.ranges
      print(ranges._0)        // Index(_rawBits: 1)..<Index(_rawBits: 655617)
      print(ranges._1)        // Index(_rawBits: 1)..<Index(_rawBits: 262401)
      print(ranges._2!)       // Index(_rawBits: 393473)..<Index(_rawBits: 655617)
    }
  }

  func testScalars() {
    // let regex = /(?<lower>[0-9A-F]+)(?:\.\.(?<upper>[0-9A-F]+))?/
    let str = "007F..009F    ; Control # Cc  [33] <control-007F>..<control-009F>"

    let l1 = str.unicodeScalars.startIndex
    let u1 = str.unicodeScalars.index(l1, offsetBy: 4)
    let r1 = l1..<u1

    let l2 = str.unicodeScalars.index(str.startIndex, offsetBy: 6)
    let u2 = str.unicodeScalars.index(l2, offsetBy: 4)
    let r2 = l2..<u2

    let r0 = l1..<u2

    let regex = Regex<Tuple3<Submatch, Submatch, Submatch?>>(
      _match: .tuple([.range(r0), .range(r1), .optional(.range(r2))]))

    if let result = str.unicodeScalars.firstMatch(of: regex) {
      print(type(of: result)) // MatchResult<Tuple3<Submatch, Submatch, Optional<Submatch>>>
      print(result._0)        // 007F..009F
      print(result._1)        // 007F
      print(result._2!)       // 009F

      let ranges = result.ranges
      print(ranges._0)        // Index(_rawBits: 1)..<Index(_rawBits: 655617)
      print(ranges._1)        // Index(_rawBits: 1)..<Index(_rawBits: 262401)
      print(ranges._2!)       // Index(_rawBits: 393473)..<Index(_rawBits: 655617)
    }
  }
}
