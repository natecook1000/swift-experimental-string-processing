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

import XCTest
@testable import _StringProcessing

class UnicodeTests: XCTestCase {}

/// Test the case folding and decomposition of a string.
///
/// - Parameters:
///   - initial: The original string to case fold and/or decompose.
///   - decomposed: The result of canonical decomposition.
///   - folded: The result of case folding.
///   - decomposedAndFolded: The result of decomposing and then case folding.
///   - foldedAndDecomposed: The result of case folding and then decomposing.
///     Pass `nil` if this should be the same result as `decomposedAndFolded.`
///   - decomposedFoldedAndDecomposed: The result of decomposing, case folding,
///     and then decomposing again. Pass `nil` if this should be the same
///     result as `decomposedAndFolded.`
func _testFoldingAndDecomposition(
  initial: String,
  decomposed: String,
  folded: String,
  decomposedAndFolded: String,
  foldedAndDecomposed: String?,
  decomposedFoldedAndDecomposed: String?,
  file: StaticString = #file, line: UInt = #line)
{
  XCTAssertEqual(
    Array(initial.decomposed.unicodeScalars),
    Array(decomposed.unicodeScalars),
    "Decomposed only",
    file: file, line: line)
  XCTAssertEqual(
    Array(initial.caseFolded),
    Array(folded.unicodeScalars),
    "Case-folded only",
    file: file, line: line)
  XCTAssertEqual(
    Array(initial.decomposed.caseFolded),
    Array(decomposedAndFolded.unicodeScalars),
    "Decomposed, then case-folded",
    file: file, line: line)
  XCTAssertEqual(
    Array(initial.caseFoldedString.decomposed.unicodeScalars),
    Array((foldedAndDecomposed ?? decomposedAndFolded).unicodeScalars),
    "Case-folded, then decomposed",
    file: file, line: line)
  XCTAssertEqual(
    Array(initial.decomposed.caseFoldedString.decomposed.unicodeScalars),
    Array((decomposedFoldedAndDecomposed ?? decomposedAndFolded).unicodeScalars),
    "Decomposed, then case-folded, then decomposed",
    file: file, line: line)
}

extension UnicodeTests {
  func testCaseFolding() {
    let strasse = "Straße"
    XCTAssertEqual(strasse.caseFoldedString, "strasse")

    _testFoldingAndDecomposition(
      initial: "SŚ\u{323}",
      decomposed: "SS\u{323}\u{301}",
      folded: "sś\u{323}",
      decomposedAndFolded: "ss\u{323}\u{301}",
      foldedAndDecomposed: nil,
      decomposedFoldedAndDecomposed: nil)

    _testFoldingAndDecomposition(
      initial: "ß\u{301}\u{323}",
      decomposed: "ß\u{323}\u{301}",
      folded: "ss\u{301}\u{323}",
      decomposedAndFolded: "ss\u{323}\u{301}",
      foldedAndDecomposed: nil,
      decomposedFoldedAndDecomposed: nil)

    _testFoldingAndDecomposition(
      initial: "\u{3C9}\u{345}\u{342}",
      decomposed: "\u{3C9}\u{342}\u{345}",
      folded: "\u{3C9}\u{3B9}\u{342}",
      decomposedAndFolded: "\u{3C9}\u{342}\u{3B9}",
      foldedAndDecomposed: "\u{3C9}\u{3B9}\u{342}",
      decomposedFoldedAndDecomposed: nil)
  }
}
