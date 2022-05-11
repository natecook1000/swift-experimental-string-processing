//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import _StringProcessing
import XCTest

// TODO: Protocol-powered testing
class RegexConsumerTests: XCTestCase {

}

var enablePrinting = false
func output<T>(_ s: @autoclosure () -> T) {
  if enablePrinting {
    print(s())
  }
}

func makeSingleUseSequence<T>(element: T, count: Int) -> UnfoldSequence<T, Void> {
  var count = count
  return sequence(state: ()) { _ in
    defer { count -= 1 }
    return count > 0 ? element : nil
  }
}

struct CountedOptionSet: OptionSet {
  static var arrayLiteralCreationCount = 0
  
  var rawValue: Int
  
  static var one = Self(rawValue: 1)
  static var two = Self(rawValue: 1)
}

extension CountedOptionSet {
  init(arrayLiteral: Self...) {
    Self.arrayLiteralCreationCount += 1
    self.rawValue = 0
    for element in arrayLiteral {
      self.insert(element)
    }
  }
}

class AlgorithmTests: XCTestCase {
  func testContains() {
    XCTAssertTrue("abcde".contains("a"))
    XCTAssertTrue("abcde".contains("e" as Character))

    XCTAssertTrue("".contains(""))
    XCTAssertTrue("abcde".contains(""))
    XCTAssertTrue("abcde".contains("abcd"))
    XCTAssertTrue("abcde".contains("bcde"))
    XCTAssertTrue("abcde".contains("bcd"))
    XCTAssertTrue("ababacabababa".contains("abababa"))
    
    XCTAssertFalse("".contains("abcd"))
    
    for start in 0..<9 {
      for end in start..<9 {
        XCTAssertTrue((0..<10).contains(start...end))
        XCTAssertFalse((0..<10).contains(start...10))
      }
    }
  }
  
  func testContainsSourceCompatibility() {
    CountedOptionSet.arrayLiteralCreationCount = 0
    
    let both: CountedOptionSet = [.one, .two]
    let none: CountedOptionSet = []
    XCTAssertEqual(CountedOptionSet.arrayLiteralCreationCount, 2)
    
    let cosArray = [both, .one, .two]
    XCTAssertFalse(cosArray.contains(none))
    
    // This tests that `contains([])` uses the element-based `contains(_:)`
    // method, interpreting `[]` as an instance of `CountedOptionSet`, rather
    // than the collection-based overload, which would interpret `[]` as an
    // `Array<CountedOptionSet>`.
    XCTAssertFalse(cosArray.contains([]))
    XCTAssertEqual(CountedOptionSet.arrayLiteralCreationCount, 3)
  }
  
  func testRegexRanges() {
    func expectRanges(
      _ string: String,
      _ regex: String,
      _ expected: [Range<Int>],
      file: StaticString = #file, line: UInt = #line
    ) {
      let regex = try! Regex(regex)
      
      let actualSeq: [Range<Int>] = string[...].ranges(of: regex).map(string.offsets(of:))
      XCTAssertEqual(actualSeq, expected, file: file, line: line)

      // `IndexingIterator` tests the collection conformance
      let actualCol: [Range<Int>] = string[...].ranges(of: regex)[...].map(string.offsets(of:))
      XCTAssertEqual(actualCol, expected, file: file, line: line)
      
      let firstRange = string.firstRange(of: regex).map(string.offsets(of:))
      XCTAssertEqual(firstRange, expected.first, file: file, line: line)
    }

    expectRanges("", "", [0..<0])
    expectRanges("", "x", [])
    expectRanges("", "x+", [])
    expectRanges("", "x*", [0..<0])
    expectRanges("aaa", "a*", [0..<3, 3..<3])
    expectRanges("abc", "", [0..<0, 1..<1, 2..<2, 3..<3])
    expectRanges("abc", "x", [])
    expectRanges("abc", "x+", [])
    expectRanges("abc", "x*", [0..<0, 1..<1, 2..<2, 3..<3])
    expectRanges("abc", "a", [0..<1])
    expectRanges("abc", "a*", [0..<1, 1..<1, 2..<2, 3..<3])
    expectRanges("abc", "a+", [0..<1])
    expectRanges("abc", "a|b", [0..<1, 1..<2])
    expectRanges("abc", "a|b+", [0..<1, 1..<2])
    expectRanges("abc", "a|b*", [0..<1, 1..<2, 2..<2, 3..<3])
    expectRanges("abc", "(a|b)+", [0..<2])
    expectRanges("abc", "(a|b)*", [0..<2, 2..<2, 3..<3])
    expectRanges("abc", "(b|c)+", [1..<3])
    expectRanges("abc", "(b|c)*", [0..<0, 1..<3, 3..<3])
  }
  
  func testStringRanges() {
    func expectRanges(
      _ input: String,
      _ pattern: String,
      _ expected: [Range<Int>],
      file: StaticString = #file, line: UInt = #line
    ) {
      let actualSeq: [Range<Int>] = input.ranges(of: pattern).map(input.offsets(of:))
      XCTAssertEqual(actualSeq, expected, file: file, line: line)

      // `IndexingIterator` tests the collection conformance
      let actualCol: [Range<Int>] = input.ranges(of: pattern)[...].map(input.offsets(of:))
      XCTAssertEqual(actualCol, expected, file: file, line: line)
      
      let firstRange = input.firstRange(of: pattern).map(input.offsets(of:))
      XCTAssertEqual(firstRange, expected.first, file: file, line: line)
    }

    expectRanges("", "", [0..<0])
    expectRanges("abcde", "", [0..<0, 1..<1, 2..<2, 3..<3, 4..<4, 5..<5])
    expectRanges("abcde", "abcd", [0..<4])
    expectRanges("abcde", "bcde", [1..<5])
    expectRanges("abcde", "bcd", [1..<4])
    expectRanges("ababacabababa", "abababa", [6..<13])
    expectRanges("ababacabababa", "aba", [0..<3, 6..<9, 10..<13])
  }

  func testRegexSplit() {
    func expectSplit(
      _ string: String,
      _ regex: String,
      _ expected: [Substring],
      file: StaticString = #file, line: UInt = #line
    ) {
      let regex = try! Regex(regex)
      let actual = Array(string.split(separator: regex, omittingEmptySubsequences: false))
      XCTAssertEqual(actual, expected, file: file, line: line)
    }

    expectSplit("", "", [""])
    expectSplit("", "x", [""])
    expectSplit("a", "", ["", "a", ""])
    expectSplit("a", "x", ["a"])
    expectSplit("a", "a", ["", ""])
    expectSplit("a____a____a", "_+", ["a", "a", "a"])
    expectSplit("____a____a____a____", "_+", ["", "a", "a", "a", ""])
  }
  
  func testStringSplit() {
    func expectSplit(
      _ string: String,
      _ separator: String,
      _ expected: [Substring],
      file: StaticString = #file, line: UInt = #line
    ) {
      let actual = Array(string.split(separator: separator, omittingEmptySubsequences: false))
      XCTAssertEqual(actual, expected, file: file, line: line)
    }

    expectSplit("", "", [""])
    expectSplit("", "x", [""])
    expectSplit("a", "", ["", "a", ""])
    expectSplit("a", "x", ["a"])
    expectSplit("a", "a", ["", ""])
    expectSplit("a__a__a", "_", ["a", "", "a", "", "a"])
    expectSplit("_a_a_a_", "_", ["", "a", "a", "a", ""])

    XCTAssertEqual("".split(separator: ""), [])
    XCTAssertEqual("".split(separator: "", omittingEmptySubsequences: false), [""])

    // Test that original `split` functions are still accessible
    let splitRef = "abcd".split
    XCTAssert(type(of: splitRef) == ((Character, Int, Bool) -> [Substring]).self)
    let splitParamsRef = "abcd".split(separator:maxSplits:omittingEmptySubsequences:)
    XCTAssert(type(of: splitParamsRef) == ((Character, Int, Bool) -> [Substring]).self)
  }
  
  func testSplitSourceCompatibility() {
    CountedOptionSet.arrayLiteralCreationCount = 0
    
    let both: CountedOptionSet = [.one, .two]
    let none: CountedOptionSet = []
    XCTAssertEqual(CountedOptionSet.arrayLiteralCreationCount, 2)
    
    let cosArray = [both, .one, .two]
    XCTAssertEqual(cosArray.split(separator: none).count, 1)
    
    // This tests that `contains([])` uses the element-based `contains(_:)`
    // method, interpreting `[]` as an instance of `CountedOptionSet`, rather
    // than the collection-based overload, which would interpret `[]` as an
    // `Array<CountedOptionSet>`.
    XCTAssertEqual(cosArray.split(separator: []).count, 1)
    XCTAssertEqual(CountedOptionSet.arrayLiteralCreationCount, 3)
  }

  func testSplitPermutations() throws {
    let splitRegex = try Regex(#"\|"#)
    XCTAssertEqual(
      "a|a|||a|a".split(separator: splitRegex),
      ["a", "a", "a", "a"])
    XCTAssertEqual(
      "a|a|||a|a".split(separator: splitRegex, omittingEmptySubsequences: false),
      ["a", "a", "", "", "a", "a"])
    XCTAssertEqual(
      "a|a|||a|a".split(separator: splitRegex, maxSplits: 2),
      ["a", "a", "||a|a"])
    
    XCTAssertEqual(
      "a|a|||a|a|||a|a|||".split(separator: "|||"),
      ["a|a", "a|a", "a|a"])
    XCTAssertEqual(
      "a|a|||a|a|||a|a|||".split(separator: "|||", omittingEmptySubsequences: false),
      ["a|a", "a|a", "a|a", ""])
    XCTAssertEqual(
      "a|a|||a|a|||a|a|||".split(separator: "|||", maxSplits: 2),
      ["a|a", "a|a", "a|a|||"])

    XCTAssertEqual(
      "aaaa".split(separator: ""),
      ["a", "a", "a", "a"])
    XCTAssertEqual(
      "aaaa".split(separator: "", omittingEmptySubsequences: false),
      ["", "a", "a", "a", "a", ""])
    XCTAssertEqual(
      "aaaa".split(separator: "", maxSplits: 2),
      ["a", "a", "aa"])
    XCTAssertEqual(
      "aaaa".split(separator: "", maxSplits: 2, omittingEmptySubsequences: false),
      ["", "a", "aaa"])

    // Fuzzing the input and parameters
    for _ in 1...1_000 {
      // Make strings that look like:
      //   "aaaaaaa"
      //   "|||aaaa||||"
      //   "a|a|aa|aa|"
      //   "|a||||aaa|a|||"
      //   "a|aa"
      let keepCount = Int.random(in: 0...10)
      let splitCount = Int.random(in: 0...10)
      let str = [repeatElement("a", count: keepCount), repeatElement("|", count: splitCount)]
        .joined()
        .shuffled()
        .joined()
      
      let omitEmpty = Bool.random()
      let maxSplits = Bool.random() ? Int.max : Int.random(in: 0...10)
      
      // Use the stdlib behavior as the expected outcome
      let expected = str.split(
        separator: "|" as Character,
        maxSplits: maxSplits,
        omittingEmptySubsequences: omitEmpty)
      let regexActual = str.split(
        separator: splitRegex,
        maxSplits: maxSplits,
        omittingEmptySubsequences: omitEmpty)
      let stringActual = str.split(
        separator: "|" as String,
        maxSplits: maxSplits,
        omittingEmptySubsequences: omitEmpty)
      XCTAssertEqual(regexActual, expected, """
        Mismatch in regex split of '\(str)', maxSplits: \(maxSplits), omitEmpty: \(omitEmpty)
          expected: \(expected.map(String.init))
          actual:   \(regexActual.map(String.init))
        """)
      XCTAssertEqual(stringActual, expected, """
        Mismatch in string split of '\(str)', maxSplits: \(maxSplits), omitEmpty: \(omitEmpty)
          expected: \(expected.map(String.init))
          actual:   \(regexActual.map(String.init))
        """)
    }
  }
  
  func testTrim() {
    func expectTrim(
      _ string: String,
      _ regex: String,
      _ expected: Substring,
      file: StaticString = #file, line: UInt = #line
    ) {
      let regex = try! Regex(regex)
      let actual = string.trimmingPrefix(regex)
      XCTAssertEqual(actual, expected, file: file, line: line)
    }

    expectTrim("", "", "")
    expectTrim("", "x", "")
    expectTrim("a", "", "a")
    expectTrim("a", "x", "a")
    expectTrim("___a", "_", "__a")
    expectTrim("___a", "_+", "a")
    
    XCTAssertEqual("".trimmingPrefix("a"), "")
    XCTAssertEqual("a".trimmingPrefix("a"), "")
    XCTAssertEqual("b".trimmingPrefix("a"), "b")
    XCTAssertEqual("a".trimmingPrefix(""), "a")
    XCTAssertEqual("___a".trimmingPrefix("_"), "__a")
    XCTAssertEqual("___a".trimmingPrefix("___"), "a")
    XCTAssertEqual("___a".trimmingPrefix("____"), "___a")
    XCTAssertEqual("___a".trimmingPrefix("___a"), "")
    
    do {
      let prefix = makeSingleUseSequence(element: "_" as Character, count: 5)
      XCTAssertEqual("_____a".trimmingPrefix(prefix), "a")
      XCTAssertEqual("_____a".trimmingPrefix(prefix), "_____a")
    }
    do {
      let prefix = makeSingleUseSequence(element: "_" as Character, count: 5)
      XCTAssertEqual("a".trimmingPrefix(prefix), "a")
      // The result of this next call is technically undefined, so this
      // is just to test that it doesn't crash.
      XCTAssertNotEqual("_____a".trimmingPrefix(prefix), "")
    }

    XCTAssertEqual("".trimmingPrefix(while: \.isWhitespace), "")
    XCTAssertEqual("a".trimmingPrefix(while: \.isWhitespace), "a")
    XCTAssertEqual("   ".trimmingPrefix(while: \.isWhitespace), "")
    XCTAssertEqual("  a".trimmingPrefix(while: \.isWhitespace), "a")
    XCTAssertEqual("a  ".trimmingPrefix(while: \.isWhitespace), "a  ")
  }
  
  func testRegexReplace() {
    func expectReplace(
      _ string: String,
      _ regex: String,
      _ replacement: String,
      _ expected: String,
      file: StaticString = #file, line: UInt = #line
    ) {
      let regex = try! Regex(regex)
      let actual = string.replacing(regex, with: replacement)
      XCTAssertEqual(actual, expected, file: file, line: line)
    }
    
    expectReplace("", "", "X", "X")
    expectReplace("", "x", "X", "")
    expectReplace("", "x*", "X", "X")
    expectReplace("a", "", "X", "XaX")
    expectReplace("a", "x", "X", "a")
    expectReplace("a", "a", "X", "X")
    expectReplace("a", "a+", "X", "X")
    expectReplace("a", "a*", "X", "XX")
    expectReplace("aab", "a", "X", "XXb")
    expectReplace("aab", "a+", "X", "Xb")
    expectReplace("aab", "a*", "X", "XXbX")
    
    // FIXME: Test maxReplacements
    // FIXME: Test closure-based replacement
  }

  func testStringReplace() {
    func expectReplace(
      _ string: String,
      _ pattern: String,
      _ replacement: String,
      _ expected: String,
      file: StaticString = #file, line: UInt = #line
    ) {
      let actual = string.replacing(pattern, with: replacement)
      XCTAssertEqual(actual, expected, file: file, line: line)
    }
    
    expectReplace("", "", "X", "X")
    expectReplace("", "x", "X", "")
    expectReplace("a", "", "X", "XaX")
    expectReplace("a", "x", "X", "a")
    expectReplace("a", "a", "X", "X")
    expectReplace("aab", "a", "X", "XXb")
    
    // FIXME: Test maxReplacements
  }
  
  func testSubstring() throws {
    let s = "aaa | aaaaaa | aaaaaaaaaa"
    let s1 = s.dropFirst(6)  // "aaaaaa | aaaaaaaaaa"
    let s2 = s1.dropLast(17) // "aa"
    let regex = try! Regex("a+")

    XCTAssertEqual(s.firstMatch(of: regex)?.0, "aaa")
    XCTAssertEqual(s1.firstMatch(of: regex)?.0, "aaaaaa")
    XCTAssertEqual(s2.firstMatch(of: regex)?.0, "aa")

    XCTAssertEqual(
      s.ranges(of: regex).map(s.offsets(of:)),
      [0..<3, 6..<12, 15..<25])
    XCTAssertEqual(
      s1.ranges(of: regex).map(s.offsets(of:)),
      [6..<12, 15..<25])
    XCTAssertEqual(
      s2.ranges(of: regex).map(s.offsets(of:)),
      [6..<8])

    XCTAssertEqual(s.replacing(regex, with: ""), " |  | ")
    XCTAssertEqual(s1.replacing(regex, with: ""), " | ")
    XCTAssertEqual(s2.replacing(regex, with: ""), "")

    XCTAssertEqual(
      s.matches(of: regex).map(\.0),
      ["aaa", "aaaaaa", "aaaaaaaaaa"])
    XCTAssertEqual(
      s1.matches(of: regex).map(\.0),
      ["aaaaaa", "aaaaaaaaaa"])
    XCTAssertEqual(
      s2.matches(of: regex).map(\.0),
      ["aa"])
  }

  func testSwitches() {
    switch "abcde" {
    case try! Regex("a.*f"):
      XCTFail()
    case try! Regex("abc"):
      XCTFail()

    case try! Regex("a.*e"):
      break // success

    default:
      XCTFail()
    }
  }
}
