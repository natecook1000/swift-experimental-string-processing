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

@_implementationOnly import _RegexParser

struct SentinelValue: Hashable, CustomStringConvertible {
  var description: String { "<value sentinel>" }
}

extension Processor {
  /// Our register file
  struct Registers {

    // MARK: static / read-only, non-resettable

    // Verbatim elements to compare against
    var elements: [Element]

    // Verbatim sequences to compare against
    //
    // TODO: Degenericize Processor and store Strings
    var sequences: [[Element]] = []

    var consumeFunctions: [MEProgram<Input>.ConsumeFunction]

    var assertionFunctions: [MEProgram<Input>.AssertionFunction]

    // Captured-value constructors
    var transformFunctions: [MEProgram<Input>.TransformFunction]

    // Value-constructing matchers
    var matcherFunctions: [MEProgram<Input>.MatcherFunction]

    // currently, these are for comments and abort messages
    var strings: [String]

    // MARK: writeable, resettable

    // currently, hold output of assertions
    var bools: [Bool] // TODO: bitset

    // currently, useful for range-based quantification
    var ints: [Int]

    // Currently, used for `movePosition` and `matchSlice`
    var positions: [Position] = []

    var values: [Any]
  }
}

extension Processor.Registers {
  subscript(_ i: StringRegister) -> String {
    strings[i.rawValue]
  }
  subscript(_ i: SequenceRegister) -> [Input.Element] {
    sequences[i.rawValue]
  }
  subscript(_ i: IntRegister) -> Int {
    get { ints[i.rawValue] }
    set { ints[i.rawValue] = newValue }
  }
  subscript(_ i: BoolRegister) -> Bool {
    get { bools[i.rawValue] }
    set { bools[i.rawValue] = newValue }
  }
  subscript(_ i: PositionRegister) -> Input.Index {
    get { positions[i.rawValue] }
    set { positions[i.rawValue] = newValue }
  }
  subscript(_ i: ValueRegister) -> Any {
    get { values[i.rawValue] }
    set {
      values[i.rawValue] = newValue
    }
  }
  subscript(_ i: ElementRegister) -> Input.Element {
    elements[i.rawValue]
  }
  subscript(_ i: ConsumeFunctionRegister) -> MEProgram<Input>.ConsumeFunction {
    consumeFunctions[i.rawValue]
  }
  subscript(_ i: AssertionFunctionRegister) -> MEProgram<Input>.AssertionFunction {
    assertionFunctions[i.rawValue]
  }
  subscript(_ i: TransformRegister) -> MEProgram<Input>.TransformFunction {
    transformFunctions[i.rawValue]
  }
  subscript(_ i: MatcherRegister) -> MEProgram<Input>.MatcherFunction {
    matcherFunctions[i.rawValue]
  }
}

extension Processor.Registers {
  init(
    _ program: MEProgram<Input>,
    _ sentinel: Input.Index
  ) {
    let info = program.registerInfo

    self.elements = program.staticElements
    assert(elements.count == info.elements)

    self.sequences = program.staticSequences
    assert(sequences.count == info.sequences)

    self.consumeFunctions = program.staticConsumeFunctions
    assert(consumeFunctions.count == info.consumeFunctions)

    self.assertionFunctions = program.staticAssertionFunctions
    assert(assertionFunctions.count == info.assertionFunctions)

    self.transformFunctions = program.staticTransformFunctions
    assert(transformFunctions.count == info.transformFunctions)

    self.matcherFunctions = program.staticMatcherFunctions
    assert(matcherFunctions.count == info.matcherFunctions)

    self.strings = program.staticStrings
    assert(strings.count == info.strings)

    self.bools = Array(repeating: false, count: info.bools)

    self.ints = Array(repeating: 0, count: info.ints)

    self.positions = Array(repeating: sentinel, count: info.positions)

    self.values = Array(
      repeating: SentinelValue(), count: info.values)
  }

  mutating func reset(sentinel: Input.Index) {
    self.bools._setAll(to: false)
    self.ints._setAll(to: 0)
    self.positions._setAll(to: sentinel)
    self.values._setAll(to: SentinelValue())
  }
}

// TODO: Productize into general algorithm
extension MutableCollection {
  mutating func _setAll(to e: Element) {
    for idx in self.indices {
      self[idx] = e
    }
  }
}

extension MEProgram {
  struct RegisterInfo {
    var elements = 0
    var sequences = 0
    var bools = 0
    var strings = 0
    var consumeFunctions = 0
    var assertionFunctions = 0
    var transformFunctions = 0
    var matcherFunctions = 0
    var ints = 0
    var floats = 0
    var positions = 0
    var values = 0
    var instructionAddresses = 0
    var classStackAddresses = 0
    var positionStackAddresses = 0
    var savePointAddresses = 0
    var captures = 0
  }
}

extension Processor.Registers: CustomStringConvertible {
  var description: String {
    func formatRegisters<T>(
      _ name: String, _ regs: [T]
    ) -> String {
      // TODO: multi-line if long
      if regs.isEmpty { return "" }

      return "\(name): \(regs)\n"
    }

    return """
      \(formatRegisters("elements", elements))\
      \(formatRegisters("bools", bools))\
      \(formatRegisters("strings", strings))\
      \(formatRegisters("ints", ints))\
      \(formatRegisters("positions", positions))\

      """    
  }
}

