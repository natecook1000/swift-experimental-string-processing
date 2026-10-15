//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import Testing
@testable @_spi(RegexBuilder) @_spi(RegexBenchmark) import _StringProcessing
@testable import _RegexParser

@Suite struct OptimizationTests {
  @available(SwiftStdlib 6.0, *)
  @Test(arguments: [#/a/#, #/a+/#, #/(?:a+)/#, #/(?:a)+/#, #/(?m)a+/#, #/ab?c/#, #/(?:a+)+$/#, #/(?:(?:a+b)+b)/#])
  func requiredFirstAtom(pattern: Regex<Substring>) throws {
    let list = pattern.program.list
    let atom = list.requiredFirstAtom(allowOptionsChanges: true)
    #expect(atom?.literalCharacterValue == "a", "Missing first character atom in '\(pattern._literalPattern!)'")
  }
  
  @available(SwiftStdlib 6.0, *)
  @Test(arguments: [#/a?/#, #/(?:a|b)/#, #/[a]/#, #/a?bc/#])
  func noRequiredFirstAtom(pattern: Regex<Substring>) throws {
    let list = pattern.program.list
    let atom = list.requiredFirstAtom(allowOptionsChanges: true)
    #expect(atom == nil, "Unexpected required first atom in '\(pattern._literalPattern!)'")
  }
  
  @available(SwiftStdlib 6.0, *)
  @Test(arguments: [#/a+b/#, #/a*b/#, #/\w+\s/#, #/(?:a+b|b+a)/#, #/\d+a/#, #/a+A/#])
  func autoPossessify(pattern: Regex<Substring>) throws {
    var list = pattern.program.list
    list.autoPossessify()
    for node in list.nodes {
      switch node {
      case .quantification(_, let kind):
        #expect(
          kind.isExplicit && kind.quantificationKind?.ast == .possessive,
          "Expected possessification in '\(pattern._literalPattern!)'")
      default: break
      }
    }
  }

  @available(SwiftStdlib 6.0, *)
  @Test(arguments: [
    #/a?/#, #/a+a/#, #/a+(?:b|c)/#, #/(?:a+|b+)/#, #/[a]/#, #/a?a/#,
    #/(?i)a+A/#, #/(?i:a+A)/#,  // case insensitivity when checking exclusion
    #/(?:(?:ab)+b)/#,           // single atom quantifications only
  ])
  func noAutoPossessify(pattern: Regex<Substring>) throws {
    var list = pattern.program.list
    list.autoPossessify()
    for node in list.nodes {
      switch node {
      case .quantification(_, let kind):
        #expect(
          kind.quantificationKind?.ast != .possessive,
          "Unexpected possessification in '\(pattern._literalPattern!)'")
      default: break
      }
    }
  }
}

@Suite struct FirstBytePrefilterTests {
  typealias AsciiBitset = DSLTree.CustomCharacterClass.AsciiBitset

  @available(SwiftStdlib 5.7, *)
  private func set(_ pattern: String) throws -> AsciiBitset? {
    try Regex(pattern).program.list.firstByteSet(MatchingOptions())
  }
  
  private func members(_ s: AsciiBitset?) -> String {
    s.map { s in
      String(decoding: (0..<128).filter { s.matches(UInt8($0)) }.map { UInt8($0) },
             as: UTF8.self)
    } ?? ""
  }

  @available(SwiftStdlib 5.7, *)
  @Test func computesSet() throws {
    let cases: [(String, String)] = [
      (#"abc"#, "a"),
      (#"[xyz]foo"#, "xyz"),
      (#"(?i)abc"#, "Aa"),
      (#"(?i)[a-c]x"#, "ABCabc"),
      (#"foo|bar"#, "bf"),
      
      // Leading nullable element
      (#"a?bc"#, "ab"),
      (#"a*bc"#, "ab"),
      (#"a?b??c+d"#, "abc"),
      (#"(?:xy)?z"#, "xz"),
      
      // Leading assertion
      (#"\bword"#, "w"),
      (#"(?=.*q)abc"#, "a"),
      
      // Groups and captures
      (#"(?:(?:ab))"#, "a"),
      (#"(abc)"#, "a"),
    ]
    for (pattern, expected) in cases {
      let s = try #require(try set(pattern), "no set for '\(pattern)'")
      #expect(members(s) == String(expected.sorted()),
              "wrong set for '\(pattern)'")
    }
  }

  @available(SwiftStdlib 5.7, *)
  @Test func noSet() throws {
    let cases = [
      #"a*"#,          // can match empty
      #".foo"#,        // `.` is unconstrained
      #"\wfoo"#,       // builtin character classes are skipped
      #"(?:a|.)x"#,    // one branch is unconstrained
      #"\u{e9}abc"#,   // non-ASCII first character
      #"(?=abc)"#,     // zero-width overall
    ]
    for pattern in cases {
      #expect(try set(pattern) == nil, "unexpected set for '\(pattern)'")
    }
  }

  @available(SwiftStdlib 5.7, *)
  @Test func overBroadSetIsRejected() throws {
    #expect(try set(#"[a-zA-Z0-9.]x"#) != nil)
    #expect(try set(#"[a-zA-Z0-9._]x"#) == nil) // too many!
  }

  // MARK: Non-ASCII scalars that match an ASCII character

  @available(SwiftStdlib 5.7, *)
  @Test func canonicalEquivalentsAreNotSkipped() throws {
    for (ascii, scalar) in CanonicalEquivalenceTests.asciiEquivalentScalars {
      let set = AsciiBitset(UInt8(ascii: ascii), false, false)
      // Long enough that a bulk search would stride well past the scalar.
      let subject = String(repeating: "x", count: 100) + String(scalar) + "yy"
      let target = subject.unicodeScalars.firstIndex(of: scalar)!

      // The prefilter should stop at the scalar when in grapheme cluster mode,
      // but otherwise continue to the end.
      for isGraphemeSemantic in [true, false] {
        let found = subject._nextPossibleMatchStart(
          of: set,
          low: subject.startIndex,
          high: subject.endIndex,
          isGraphemeSemantic: isGraphemeSemantic)
        #expect(
          isGraphemeSemantic == (found <= target),
          """
          scan skipped past U+\(String(scalar.value, radix: 16, uppercase: true)), \
          which matches '\(ascii)' (grapheme semantics: \(isGraphemeSemantic))
          """)
      }
    }
  }
}
