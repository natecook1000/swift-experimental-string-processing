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

internal import _RegexParser

// Support for building & using a prefilter over the ASCII bytes that a match
// can start with.

extension String {
  /// Returns the first position at or after `low`, and at or before `high`,
  /// at which a match beginning with one of `set`'s bytes could start.
  func _nextPossibleMatchStart(
    of set: DSLTree.CustomCharacterClass.AsciiBitset,
    low: Index,
    high: Index,
    isGraphemeSemantic: Bool
  ) -> Index {
    assert(!set.isInverted)
    if let offset = utf8[Range(uncheckedBounds: (low, high))].withContiguousStorageIfAvailable({
      buffer in
      if let singleByte = set._singleASCIIByte,
          !isGraphemeSemantic || !singleByte._hasNonASCIICanonicalEquivalent
      {
        _firstOffset(of: singleByte, in: buffer, isGraphemeSemantic: isGraphemeSemantic)
      } else {
        _nextPossibleMatchStartOffset(of: set, in: buffer, isGraphemeSemantic: isGraphemeSemantic)
      }
    }) {
      return utf8.index(low, offsetBy: offset)
    }
    
    return _nextPossibleMatchStartSlow(
      in: set,
      low: low,
      high: high,
      isGraphemeSemantic: isGraphemeSemantic)
  }

  /// The offset within the buffer of the first byte that could begin a match, or
  /// `buffer.count` if there is none.
  private func _nextPossibleMatchStartOffset(
    of set: DSLTree.CustomCharacterClass.AsciiBitset,
    in buffer: UnsafeBufferPointer<UInt8>,
    isGraphemeSemantic: Bool
  ) -> Int {
    guard let base = buffer.baseAddress else { return 0 }
    let count = buffer.count
    var i = 0
    var lastValidOffset = 0  // The last-know valid character start
    var previousWasCR = false

    while i < count {
      let byte = base[i]

      guard byte < 0x80 else {
        return isGraphemeSemantic ? lastValidOffset : i
      }

      // In grapheme semantics the LF of a CR-LF is the middle of a character,
      // so it's an invalid matching start.
      let isInsideCRLF =
        isGraphemeSemantic && previousWasCR && byte == UInt8._lineFeed
      if set.matches(byte) && !isInsideCRLF {
        return i
      }

      if !isInsideCRLF {
        lastValidOffset = i
      }
      previousWasCR = byte == UInt8._carriageReturn
      i &+= 1
    }
    return count
  }

  /// The offset of the first occurrence of the given byte, or `count` if there is
  /// none.
  private func _firstOffset(
    of needle: UInt8,
    in buffer: UnsafeBufferPointer<UInt8>,
    isGraphemeSemantic: Bool
  ) -> Int {
    guard let base = buffer.baseAddress else { return 0 }
    let count = buffer.count
    // Every ASCII byte begins a new grapheme except the LF of a CR-LF, so
    // that is the only needle needing a second look.
    let checkCRLF = isGraphemeSemantic && needle == UInt8._lineFeed
    var i = 0
    
    while true {
      i = _bulkFirstOffset(of: needle, base: base, count: count, from: i)
      guard i < count else { return count }
      // Offset 0 is `low` itself, which the general scan never rejects
      // either, so leave it alone.
      if checkCRLF, i > 0, base[i - 1] == UInt8._carriageReturn {
        i += 1
        continue
      }
      return i
    }
  }

  /// Returns the offset of the specified byte in the given buffer,
  /// or `count` if there is none, using SIMD for bulk searching.
  @inline(__always)
  private func _bulkFirstOffset(
    of needle: UInt8,
    base: UnsafePointer<UInt8>,
    count: Int,
    from start: Int
  ) -> Int {
    var i = start
    // Small linear probe before dropping to bulk search
    let probeEnd = Swift.min(count, i &+ 4)
    while i < probeEnd {
      if base[i] == needle { return i }
      i &+= 1
    }
    
    let needles = SIMD16<UInt8>(repeating: needle)
    while i &+ 16 <= count {
      let chunk = UnsafeRawPointer(base + i)
        .loadUnaligned(as: SIMD16<UInt8>.self)

      if Swift.any(chunk .== needles) {
        for j in i..<(i &+ 16) {
          if base[j] == needle { return j }
        }
        fatalError()
      }
      i &+= 16
    }
    
    // Search the remainder
    for j in i..<count {
      if base[j] == needle { return j }
    }
    return count
  }

  /// `_nextPossibleMatchStart` for strings with no contiguous UTF-8 storage.
  private func _nextPossibleMatchStartSlow(
    in set: DSLTree.CustomCharacterClass.AsciiBitset,
    low: Index,
    high: Index,
    isGraphemeSemantic: Bool
  ) -> Index {
    let utf8 = self.utf8
    var i = low
    var lastSafe = low
    var prevWasCR = false

    while i < high {
      let byte = utf8[i]
      guard byte < 0x80 else {
        return isGraphemeSemantic ? lastSafe : i
      }
      let isInteriorLF =
        isGraphemeSemantic && prevWasCR && byte == UInt8._lineFeed
      if set.matches(byte) && !isInteriorLF {
        return i
      }
      if !isInteriorLF {
        lastSafe = i
      }
      prevWasCR = byte == UInt8._carriageReturn
      utf8.formIndex(after: &i)
    }
    return high
  }
}

extension DSLTree.CustomCharacterClass.AsciiBitset {
  /// Whether this set is selective enough to be worth using as a prefilter.
  var _isSelectivePrefilter: Bool {
    assert(!isInverted)
    let threshold = 64
    return a.nonzeroBitCount + b.nonzeroBitCount < threshold
  }

  /// The single ASCII byte in this set, or `nil` if it holds none or several.
  ///
  var _singleASCIIByte: UInt8? {
    assert(!isInverted)
    guard a.nonzeroBitCount + b.nonzeroBitCount == 1 else { return nil }
    return a != 0
      ? UInt8(truncatingIfNeeded: a.trailingZeroBitCount)
      : UInt8(truncatingIfNeeded: 64 + b.trailingZeroBitCount)
  }
}

extension DSLList {
  typealias AsciiBitset = DSLTree.CustomCharacterClass.AsciiBitset

  /// What a subpattern can begin with.
  private struct Prefix {
    /// The ASCII bytes the subpattern can begin with (non-inverted).
    var set: AsciiBitset
    /// Whether the subpattern can match without consuming anything.
    var isNullable: Bool

    /// A subpattern that consumes nothing, such as an assertion.
    static var zeroWidth: Prefix {
      .init(set: AsciiBitset(isInverted: false), isNullable: true)
    }

    /// A subpattern that must consume `byte`, or its case-folded counterpart.
    static func byte(_ byte: UInt8, caseInsensitive: Bool) -> Prefix {
      var set = AsciiBitset(isInverted: false)
      set.add(byte, caseInsensitive)
      return .init(set: set, isNullable: false)
    }
  }

  /// Returns the set of ASCII bytes that any match of this pattern _must_ begin
  /// with, or `nil` if no useful set can be determined.
  ///
  /// The returned set is non-exhaustive: it never excludes a position where a match
  /// could start, but it does allow positions where a match could not start.
  func firstByteSet(_ options: MatchingOptions) -> AsciiBitset? {
    var options = options
    var position = 0
    guard let prefix = _firstByteSetImpl(&position, options: &options),
          !prefix.isNullable,
          prefix.set._isSelectivePrefilter
    else { return nil }
    return prefix.set
  }

  private func _firstByteSetImpl(
    _ position: inout Int,
    options: inout MatchingOptions
  ) -> Prefix? {
    guard position < nodes.count else { return .zeroWidth }

    switch nodes[position] {
    case .atom(let atom):
      return _firstBytePrefix(for: atom, options: &options)

    case .customCharacterClass(let ccc):
      // Only non-inverted classes can be used for the pre-filter.
      guard let set = ccc.asAsciiBitset(options), !set.isInverted
      else { return nil }
      return .init(set: set, isNullable: false)

    case .quotedLiteral(let str, _):
      guard let first = str.first else { return .zeroWidth }
      guard let byte = first._singleScalarAsciiValue else { return nil }
      return .byte(byte, caseInsensitive: options.isCaseInsensitive)

    case .trivia, .empty:
      return .zeroWidth

    case .concatenation(let count):
      // Collect the first byte sets of children until hitting a required
      // byte. For example, /a*b?c+d/ will have an [abc] set.
      var set = AsciiBitset(isInverted: false)
      var failed = false
      var sawNonNullable = false
      for _ in 0..<count {
        position += 1
        if failed || sawNonNullable {
          // Need to skip over remainder of concatenation after processing
          skipNode(&position)
          continue
        }
        guard let child = _firstByteSetImpl(&position, options: &options) else {
          failed = true
          continue
        }
        set = set.union(child.set)
        sawNonNullable = sawNonNullable || !child.isNullable
      }
      return failed ? nil : .init(set: set, isNullable: !sawNonNullable)

    case .orderedChoice(let count):
      // Collect first byte sets of each alternation, making this set
      // nullable if any of the branches are.
      //    /(a|b|c?)d/ -> [abcd]
      //    /(a|b|c)d/  -> [abc]
      var set = AsciiBitset(isInverted: false)
      var failed = false
      var isNullable = false
      for _ in 0..<count {
        position += 1
        if failed {
          skipNode(&position)
          continue
        }
        guard let branch = _firstByteSetImpl(&position, options: &options) else {
          failed = true
          continue
        }
        set = set.union(branch.set)
        isNullable = isNullable || branch.isNullable
      }
      return failed ? nil : .init(set: set, isNullable: isNullable)

    case .nonCapturingGroup(let kind) where kind.isLookaround:
      // TODO: Lookahead can contribute to the first-byte set
      position += 1
      skipNode(&position)
      return .zeroWidth

    case .nonCapturingGroup(let kind):
      position += 1
      options.beginScope()
      defer { options.endScope() }
      if case .changeMatchingOptions(let seq) = kind.ast {
        options.apply(seq)
      }
      return _firstByteSetImpl(&position, options: &options)

    case .capture:
      position += 1
      options.beginScope()
      defer { options.endScope() }
      return _firstByteSetImpl(&position, options: &options)

    case .ignoreCapturesInTypedOutput, .limitCaptureNesting:
      position += 1
      return _firstByteSetImpl(&position, options: &options)

    case .quantification(let amount, _):
      position += 1
      guard let child = _firstByteSetImpl(&position, options: &options) else {
        return nil
      }
      if amount.requiresAtLeastOne {
        return child
      }
      return .init(set: child.set, isNullable: true)

    case .conditional, .consumer, .matcher, .characterPredicate,
        .absentFunction:
      return nil
    }
  }

  private func _firstBytePrefix(
    for atom: DSLTree.Atom,
    options: inout MatchingOptions
  ) -> Prefix? {
    switch atom {
    // Zero-width, but affects how the rest of the pattern is interpreted.
    case .changeMatchingOptions(let seq):
      options.apply(seq.ast)
      return .zeroWidth

    case .assertion:
      return .zeroWidth

    case .char(let c):
      guard let byte = c._singleScalarAsciiValue else { return nil }
      return .byte(byte, caseInsensitive: options.isCaseInsensitive)

    case .scalar(let s):
      guard s.isASCII else { return nil }
      return .byte(UInt8(s.value), caseInsensitive: options.isCaseInsensitive)

    case .any, .anyNonNewline, .dot, .characterClass, .backreference,
        .symbolicReference, .unconverted:
      return nil
    }
  }
}
