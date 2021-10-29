import XCTest
@testable import RegexDSL
import Regex
import Util

class RegexDSLTests: XCTestCase {
  static let engines: [VirtualMachine.Type] = [HareVM.self, TortoiseVM.self]

  func forEachEngine(
    except exceptions: VirtualMachine.Type...,
    do body: (VirtualMachine.Type) throws -> Void
  ) rethrows -> Void {
    for engine in Self.engines {
      if !exceptions.contains(where: { $0 == engine }) {
        try body(engine)
      }
    }
  }

  func testSimpleStrings() throws {
    let regex = Regex {
      "a"
      Character("b").capture() // Character
      "1".capture { Int($0)! } // Int
    }
    // Assert the inferred capture type.
    let _: (Substring, Int).Type = type(of: regex).CaptureValue.self
    try forEachEngine { engine in
      let maybeMatch = "ab1".match(regex, using: engine)
      let match = try XCTUnwrap(maybeMatch)
      XCTAssertTrue(match.captures == ("b", 1))
    }
  }

  func testCharacterClasses() throws {
    let regex = Regex {
      CharacterClass.any
      CharacterClass.whitespace.capture() // Character
      "c".capture() // Substring
    }
    // Assert the inferred capture type.
    let _: (Substring, Substring).Type = type(of: regex).CaptureValue.self
    try forEachEngine { engine in
      let maybeMatch = "a c".match(regex, using: engine)
      let match = try XCTUnwrap(maybeMatch)
      XCTAssertTrue(match.captures == (" ", "c"))
    }
  }

  func testCombinators() throws {
    let regex = Regex {
      "a".+
      OneOrMore(Character("b")).capture() // [Character]
      Repeat("c").capture() // [Substring]
      CharacterClass.hexDigit.capture().* // [Character]
      "e".?
      ("t" | "k").capture() // Substring
    }
    // Assert the inferred capture type.
    let _: (Substring, Substring, [Substring], Substring).Type
      = type(of: regex).CaptureValue.self
    try forEachEngine { engine in
      let maybeMatch = "aaaabccccdddk".match(regex, using: engine)
      let match = try XCTUnwrap(maybeMatch)
      XCTAssertTrue(
        match.captures
          == ("b", "cccc", ["d", "d", "d"], "k"))
    }
  }

  func testNestedGroups() throws {
    let regex = Regex {
      "a".+
      OneOrMore {
        OneOrMore("b").capture()
        Repeat("c").capture()
        "d".capture().*
        "e".?
      }
    }
    // Assert the inferred capture type.
    let _: [(Substring, Substring, [Substring])].Type = type(of: regex).CaptureValue.self
    try forEachEngine { engine in
      let maybeMatch = "aaaabccccddd".match(regex, using: engine)
      let match = try XCTUnwrap(maybeMatch)
      XCTAssertEqual(match.captures.count, 1)
      XCTAssertTrue(
        match.captures[0]
          == ("b", "cccc", ["d", "d", "d"]))
    }
  }

  func testUnicodeScalarPostProcessing() throws {
    let spaces = Regex {
      Repeat {
        CharacterClass.whitespace
      }
    }

    let unicodeScalar = Regex {
      OneOrMore {
        CharacterClass.hexDigit
      }
      spaces
    }

    let unicodeData = Regex {
      unicodeScalar
      Optionally {
        ".."
        unicodeScalar
      }

      ";"
      spaces

      OneOrMore {
        CharacterClass.word
      }.capture()

      Repeat {
        CharacterClass.any
      }
    }

    // Assert the inferred capture type.
    let _: Substring.Type = type(of: unicodeData).CaptureValue.self

    try forEachEngine { engine in
      let unicodeLine =
        "1BCA0..1BCA3  ; Control # Cf   [4] SHORTHAND FORMAT LETTER OVERLAP..SHORTHAND FORMAT UP STEP"
      let match = try XCTUnwrap(unicodeLine.match(unicodeData, using: engine))
      XCTAssertEqual(match.captures, "Control")
    }
  }

  func testGraphemeBreakData() throws {
    let line = """
      A6F0..A6F1    ; Extend # Mn   [2] BAMUM COMBINING MARK KOQNDON..BAMUM COMBINING MARK TUKWENTIS
      """
    let regex = Regex {
      OneOrMore(CharacterClass.hexDigit).capture()
      Optionally {
        ".."
        OneOrMore(CharacterClass.hexDigit).capture()
      }
      OneOrMore(CharacterClass.whitespace)
      ";"
      OneOrMore(CharacterClass.whitespace)
      OneOrMore(CharacterClass.word).capture()
      Repeat(CharacterClass.any)
    }
    // Assert the inferred capture type.
    typealias Capture = (Substring, Substring?, Substring)
    let _: Capture.Type = type(of: regex).CaptureValue.self
    func run<R: RegexProtocol>(
      _ regex: R
    ) throws where R.CaptureValue == Capture {
      try forEachEngine { engine in
        let maybeMatchResult = line.match(regex, using: engine)
        let matchResult = try XCTUnwrap(maybeMatchResult)
        let (lower, upper, propertyString) = matchResult.captures
        XCTAssertEqual(lower, "A6F0")
        XCTAssertEqual(upper, "A6F1")
        XCTAssertEqual(propertyString, "Extend")
      }
    }
    let regexLiteral = try MockRegexLiteral(
        #"([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s+;\s+(\w+).*"#,
        capturing: (Substring, Substring?, Substring).self)
    try run(regex)
    try run(regexLiteral)
  }
  
  func testFirstMatch() throws {
    let regex = Regex {
      CharacterClass.whitespace // Character
      OneOrMore("c").capture() // Substring
    }
    // Assert the inferred capture type.
    let _: (Substring).Type = type(of: regex).CaptureValue.self
    let tests: [(input: String, captures: Substring?)] = [
      ("a c", "c"),
      ("aaaa c", "c"),
      ("aaaa ccccc", "ccccc"),
      // TODO: Captures are greedy, so this doesn't return the 1st match
      ("a ccccc     bbbb c", "ccccc"),
    ]
    
    try forEachEngine { engine in
      for (input, maybeExpected) in tests {
        let maybeMatch = input.matchFirst(regex, using: engine, mode: .partialFromFront)
        if let expected = maybeExpected {
          let match = try XCTUnwrap(maybeMatch)
          print(match.captures, expected)
          XCTAssert(match.captures == expected)
        } else {
          XCTAssertNil(maybeMatch)
        }
      }
    }
  }
}
