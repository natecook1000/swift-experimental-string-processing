//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

import _StringProcessing

extension Inputs {
  /// Generates sample text with a marker character at the specified density.
  static func firstByteFiller(
    marker: Character,
    everyNBytes: Int,
    totalBytes: Int = 1 << 20,
    nonASCIIEveryNBytes: Int = 0
  ) -> String {
    let characters = "abcdefghijklmnopqrstuvwxyz ,.;:'-_()[]\n"
      .filter { $0 != marker }
    var result = ""
    
    var rng = SplitMix64(seed: seed)
    var i = 0
    while result.utf8.count < totalBytes {
      if i.isMultiple(of: everyNBytes) {
        result.append(marker)
      } else if nonASCIIEveryNBytes > 0, i.isMultiple(of: nonASCIIEveryNBytes) {
        result.append("é")
      } else {
        result.append(characters.randomElement(using: &rng)!)
      }
      i += 1
    }
    return result
  }

  static let seed: UInt64 = 8675309
  
  static let firstByteSparse = firstByteFiller(marker: "Q", everyNBytes: 4096)
  static let firstByteModerate = firstByteFiller(marker: "Q", everyNBytes: 256)
  static let firstByteDense = firstByteFiller(marker: "Q", everyNBytes: 16)
  static let firstByteOopsAllMarkers = String(repeating: "Q", count: 1 << 20)
  static let firstByteMixedUnicode = firstByteFiller(
    marker: "Q", everyNBytes: 4096, nonASCIIEveryNBytes: 64)
}

extension BenchmarkRunner {
  /// Benchmarks for the first-byte prefilter.
  mutating func addFirstBytePrefilter() {
    CrossBenchmark(
      baseName: "FirstByteSparse",
      regex: #"Q[0-9]{4}"#,
      input: Inputs.firstByteSparse,
      includeFirst: true
    ).register(&self)

    CrossBenchmark(
      baseName: "FirstByteModerate",
      regex: #"Q[0-9]{4}"#,
      input: Inputs.firstByteModerate,
      includeFirst: true
    ).register(&self)

    CrossBenchmark(
      baseName: "FirstByteDense",
      regex: #"Q[0-9]{4}"#,
      input: Inputs.firstByteDense,
      includeFirst: true
    ).register(&self)

    CrossBenchmark(
      baseName: "FirstByteMixedUnicode",
      regex: #"Q[0-9]{4}"#,
      input: Inputs.firstByteMixedUnicode,
      includeFirst: true
    ).register(&self)

    CrossBenchmark(
      baseName: "FirstByteNotFound",
      regex: #"ZZZZ"#,
      input: Inputs.firstByteSparse,
      includeFirst: true
    ).register(&self)

    CrossBenchmark(
      baseName: "FirstByteAllMarkers",
      regex: #"Q[0-9]{4}"#,
      input: Inputs.firstByteOopsAllMarkers,
      includeFirst: true
    ).register(&self)

    // A multi-char first-byte set over the same input.
    CrossBenchmark(
      baseName: "FirstByteSetOfFour",
      regex: #"[QXYZ][0-9]{4}"#,
      input: Inputs.firstByteSparse,
      includeFirst: true
    ).register(&self)
  }
}
