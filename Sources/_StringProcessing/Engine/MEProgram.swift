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

internal import _RegexParser

struct MEProgram {
  typealias Input = String

  typealias ConsumeFunction = (Input, Range<Input.Index>) -> Input.Index?
  typealias TransformFunction =
    (Input, Processor._StoredCapture) throws -> Any?
  typealias MatcherFunction =
    (Input, Input.Index, Range<Input.Index>) throws -> (Input.Index, Any)?

  var instructions: InstructionList<Instruction>
  var wholeMatchValueRegister: ValueRegister?

  let captureList: CaptureList
  let referencedCaptureOffsets: [ReferenceID: Int]

  /// Attributes describing how this program matches, particularly at the start.
  struct MatchingAttributes: OptionSet {
    var rawValue: UInt8

    /// The pattern can only match at the start of the subject, so failing
    /// there means the whole search fails.
    static var canOnlyMatchAtStart: Self { Self(rawValue: 1 << 0) }

    /// The first ASCII bitset register holds an ASCII bitset that any
    /// match must begin with, for skipping candidate start positions.
    static var hasFirstByteSet: Self { Self(rawValue: 1 << 1) }

    /// The pattern starts with grapheme-cluster semantics rather than
    /// Unicode scalar semantics.
    static var isGraphemeSemantic: Self { Self(rawValue: 1 << 2) }

    static var enableTracing: Self { Self(rawValue: 1 << 3) }
    static var enableMetrics: Self { Self(rawValue: 1 << 4) }
    
    init(rawValue: UInt8) {
      self.rawValue = rawValue
    }
    
    init(
      canOnlyMatchAtStart: Bool = false,
      hasFirstByteSet: Bool = false,
      isGraphemeSemantic: Bool = false,
      enableTracing: Bool = false,
      enableMetrics: Bool = false,
    ) {
      self = []
      if canOnlyMatchAtStart { insert(.canOnlyMatchAtStart) }
      if hasFirstByteSet { insert(.hasFirstByteSet) }
      if isGraphemeSemantic { insert(.isGraphemeSemantic) }
      if enableTracing { insert(.enableTracing) }
      if enableMetrics { insert(.enableMetrics) }
    }
  }

  var matchingAttributes: MatchingAttributes

  var canOnlyMatchAtStart: Bool {
    matchingAttributes.contains(.canOnlyMatchAtStart)
  }

  var hasFirstByteSet: Bool {
    matchingAttributes.contains(.hasFirstByteSet)
  }
  
  var firstByteSet: DSLTree.CustomCharacterClass.AsciiBitset? {
    hasFirstByteSet ? registers[AsciiBitsetRegister(0)] : nil
  }

  var isGraphemeSemantic: Bool {
    matchingAttributes.contains(.isGraphemeSemantic)
  }

  var enableTracing: Bool {
    matchingAttributes.contains(.enableTracing)
  }

  var enableMetrics: Bool {
    matchingAttributes.contains(.enableMetrics)
  }

  // We store the initial register state in the program, so that
  // processors can be spun up quicker (useful for running same regex
  // over many, many smaller inputs).
  var registers: Processor.Registers
}

extension MEProgram: CustomStringConvertible {
  var description: String {
    // TODO: Re-instate better pretty-printing functionality

    var result = """
    Capture list: \(captureList)
    Instructions: \(instructions.count)
    Register counts:
      ints: \(registers.ints.count)
      positions: \(registers.positions.count)
      values: \(registers.values.count)
      elements: \(registers.elements.count)
      bitsets: \(registers.bitsets.count)
      consumeFunctions: \(registers.consumeFunctions.count)
      transformFunctions: \(registers.transformFunctions.count)
      matcherFunctions: \(registers.matcherFunctions.count)
    canOnlyMatchAtStart: \(canOnlyMatchAtStart)
    isGraphemeSemantic: \(isGraphemeSemantic)
    firstByteSet: \(hasFirstByteSet ? "yes" : "none")

    """
    // TODO: Extract into formatting code

    for idx in instructions.indices {
      let inst = instructions[idx]
      result += "[\(idx.rawValue)] \(inst)"
      if let ia = inst.instructionAddress {
        result += " // \(instructions[ia])"
      }
      result += "\n"
    }
    return result
  }
}
