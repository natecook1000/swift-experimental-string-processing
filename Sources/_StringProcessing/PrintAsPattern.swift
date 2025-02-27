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

// TODO: Add an expansion level, both from top to bottom.
//       After `printAsCanonical` is fleshed out, these two
//       printers can call each other. This would enable
//       incremental conversion, such that leaves remain
//       as canonical regex literals.

/// Renders an AST tree as a Pattern DSL.
///
/// - Parameters:
///   - ast: A `_RegexParser.AST` instance.
///   - maxTopDownLevels: The number of levels down from the root of the tree
///     to perform conversion. `nil` means no limit.
///   - minBottomUpLevels: The number of levels up from the leaves of the tree
///     to perform conversion. `nil` means no limit.
/// - Returns: A string representation of `ast` in the `RegexBuilder` syntax.
@_spi(PatternConverter)
public func renderAsBuilderDSL(
  ast: Any,
  maxTopDownLevels: Int? = nil,
  minBottomUpLevels: Int? = nil
) -> String {
  var printer = PrettyPrinter(
    maxTopDownLevels: maxTopDownLevels,
    minBottomUpLevels: minBottomUpLevels)
  printer.printAsPattern(ast as! AST)
  return printer.finish()
}

extension PrettyPrinter {
  /// If pattern printing should back off, prints the regex literal and returns true
  mutating func patternBackoff<T: _TreeNode>(
    _ ast: T
  ) -> Bool {
    if let max = maxTopDownLevels, depth >= max {
      return true
    }
    if let min = minBottomUpLevels, ast.height <= min {
      return true
    }
    return false
  }

  mutating func printBackoff(_ node: DSLTree.Node) {
    precondition(node.astNode != nil, "unconverted node")
    printAsCanonical(
      .init(node.astNode!, globalOptions: nil),
      delimiters: true)
  }

  mutating func printAsPattern(_ ast: AST) {
    // TODO: Handle global options...
    let node = ast.root.dslTreeNode
    
    // If we have any named captures, create references to those above the regex.
    let namedCaptures = node.getNamedCaptures()
    
    for namedCapture in namedCaptures {
      print("let \(namedCapture) = Reference(Substring.self)")
    }
    
    printBlock("Regex") { printer in
      printer.printAsPattern(convertedFromAST: node)
    }
  }

  // FIXME: Use of back-offs like height and depth
  // imply that this DSLTree node has a corresponding
  // AST. That's not always true, and it would be nice
  // to have a non-backing-off pretty-printer that this
  // can defer to.
  private mutating func printAsPattern(
    convertedFromAST node: DSLTree.Node
  ) {
    if patternBackoff(DSLTree._Tree(node)) {
      printBackoff(node)
      return
    }

    switch node {

    case let .orderedChoice(a):
      printBlock("ChoiceOf") { printer in
        a.forEach {
          printer.printAsPattern(convertedFromAST: $0)
        }
      }

    case let .concatenation(c):
      c.forEach {
        printAsPattern(convertedFromAST: $0)
      }

    case let .nonCapturingGroup(kind, child):
      switch kind.ast {
      case .atomicNonCapturing:
        printBlock("Local") { printer in
          printer.printAsPattern(convertedFromAST: child)
        }
        
      default:
        printAsPattern(convertedFromAST: child)
      }

    case let .capture(name, _, child):
      var cap = "Capture"
      if let n = name {
        cap += "(as: \(n))"
      }
      printBlock(cap) { printer in
        printer.printAsPattern(convertedFromAST: child)
      }

    case .conditional:
      print("/* TODO: conditional */")

    case let .quantification(amount, kind, child):
      let amount = amount.ast._patternBase
      var kind = kind.ast?._patternBase ?? ""
      
      // If we've updated our quantification behavior, then use that. This
      // occurs in scenarios where we use things like '(?U)' to indicate that
      // we want reluctant default quantification behavior.
      if quantificationBehavior != .eager {
        kind = quantificationBehavior._patternBase
      }
      
      var blockName = "\(amount)(\(kind))"
      
      if kind == ".eager" {
        blockName = "\(amount)"
      }
      
      // Special case single child character classes for repetition nodes.
      // This lets us do something like the following:
      //
      //     OneOrMore(.digit)
      //     vs
      //     OneOrMore {
      //       One(.digit)
      //     }
      //
      func printSimpleCCC(
        _ ccc: DSLTree.CustomCharacterClass
      ) {
        indent()
        
        if kind != ".eager" {
          blockName.removeLast()
          output("\(blockName), ")
        } else {
          output("\(blockName)(")
        }
        
        printAsPattern(ccc, wrap: false, terminateLine: false)
        output(")")
        terminateLine()
      }
      
      switch child {
      case let .customCharacterClass(ccc):
        if ccc.isSimplePrint {
          printSimpleCCC(ccc)
          return
        }
        
        break
      case let .convertedRegexLiteral(.customCharacterClass(ccc), _):
        if ccc.isSimplePrint {
          printSimpleCCC(ccc)
          return
        }
        
        break
      default:
        break
      }
      
      printBlock(blockName) { printer in
        printer.printAsPattern(convertedFromAST: child)
      }

    case let .atom(a):
      if case .unconverted(let a) = a, a.ast.isUnprintableAtom {
        print("#/\(a.ast._regexBase)/#")
        return
      }
      
      if let pattern = a._patternBase(&self) {
        print(pattern)
      }

    case .trivia:
      // We never print trivia
      break

    case .empty:
      print("")

    case let .quotedLiteral(v):
      print(v._quoted)

    case .regexLiteral:
      printBackoff(node)

    case let .convertedRegexLiteral(n, _):
      // FIXME: This recursion coordinates with back-off
      // check above, so it should work out. Need a
      // cleaner way to do this. This means the argument
      // label is a lie.
      printAsPattern(convertedFromAST: n)

    case let .customCharacterClass(ccc):
      printAsPattern(ccc)

    case .transform:
      print("/* TODO: transforms */")
    case .consumer:
      print("/* TODO: consumers */")
    case .matcher:
      print("/* TODO: consumer validators */")
    case .characterPredicate:
      print("/* TODO: character predicates */")

    case .absentFunction:
      print("/* TODO: absent function */")
    }
  }
  
  mutating func printAsPattern(
    _ ccc: DSLTree.CustomCharacterClass,
    wrap: Bool = true,
    terminateLine: Bool = true
  ) {
    if ccc.hasUnprintableProperty {
      printAsRegex(ccc, terminateLine: terminateLine)
      return
    }
    
    defer {
      if ccc.isInverted {
        printIndented { printer in
          printer.indent()
          printer.output(".inverted")
          
          if terminateLine {
            printer.terminateLine()
          }
        }
      }
    }
    
    // If we only have 1 member, then we can emit it without the extra
    // CharacterClass initialization
    if ccc.members.count == 1 {
      printAsPattern(ccc.members[0], wrap: wrap)
      
      if terminateLine {
        self.terminateLine()
      }
      
      return
    }
    
    var charMembers = ""
    

    // This iterates through all of the character class members collecting all
    // of the members who can be stuffed into a singular '.anyOf(...)' vs.
    // having multiple. This does alter the original representation, but the
    // result is the same. For example:
    //
    // Convert: '[abc\d\Qxyz\E[:space:]def]'
    //
    // CharacterClass(
    //   .anyOf("abcxyzdef"),
    //   .digit,
    //   .whitespace
    // )
    //
    // This also allows us to determine if after collecting all of the members
    // and stuffing them if we can just emit a standalone '.anyOf' instead of
    // initializing a 'CharacterClass'.
    let nonCharMembers = ccc.members.filter {
      switch $0 {
      case let .atom(a):
        switch a {
        case let .char(c):
          charMembers.append(c)
          
          if c == "\\" {
            charMembers.append(c)
          }
          
          return false
        case let .scalar(s):
          charMembers += "\\u{\(String(s.value, radix: 16, uppercase: true))}"
          return false
        case .unconverted(_):
          return true
        default:
          return true
        }
        
      case let .quotedLiteral(s):
        charMembers += s
        return false
        
      case .trivia(_):
        return false
        
      default:
        return true
      }
    }
    
    // Also in the same vein, if we have a few atom members but no
    // nonAtomMembers, then we can emit a single .anyOf(...) for them.
    if !charMembers.isEmpty, nonCharMembers.isEmpty {
      let anyOf = ".anyOf(\(charMembers._quoted))"
      
      indent()
      
      if wrap {
        output("One(\(anyOf))")
      } else {
        output(anyOf)
      }
      
      if terminateLine {
        self.terminateLine()
      }
      
      return
    }
    
    // Otherwise, use the CharacterClass initialization with multiple members.
    print("CharacterClass(")
    printIndented { printer in      
      printer.indent()
      
      if !charMembers.isEmpty {
        printer.output(".anyOf(\(charMembers._quoted))")
        
        if nonCharMembers.count > 0 {
          printer.output(",")
        }
        
        printer.terminateLine()
      }
      
      for (i, member) in nonCharMembers.enumerated() {
        printer.printAsPattern(member, wrap: false)
        
        if i != nonCharMembers.count - 1 {
          printer.output(",")
        }
        
        printer.terminateLine()
      }
    }
    
    indent()
    output(")")
    
    if terminateLine {
      self.terminateLine()
    }
  }

  // TODO: Some way to integrate this with conversion...
  mutating func printAsPattern(
    _ member: DSLTree.CustomCharacterClass.Member,
    wrap: Bool = true
  ) {
    switch member {
    case let .custom(ccc):
      printAsPattern(ccc, terminateLine: false)
      
    case let .range(lhs, rhs):
      if let lhs = lhs._patternBase(&self), let rhs = rhs._patternBase(&self) {
        indent()
        output("(")
        output(lhs)
        output("...")
        output(rhs)
        output(")")
      }
      
    case let .atom(a):
      indent()
      switch a {
      case let .char(c):
        
        if wrap {
          output("One(.anyOf(\(String(c)._quoted)))")
        } else {
          output(".anyOf(\(String(c)._quoted))")
        }
        
      case let .scalar(s):
        
        if wrap {
          output("One(.anyOf(\"\\u{\(String(s.value, radix: 16, uppercase: true))}\"))")
        } else {
          output(".anyOf(\"\\u{\(String(s.value, radix: 16, uppercase: true))}\")")
        }
        
      case let .unconverted(a):
        let base = a.ast._patternBase
        
        if base.canBeWrapped, wrap {
          output("One(\(base.0))")
        } else {
          output(base.0)
        }
      default:
        print(" // TODO: Atom \(a)")
      }
      
    case .quotedLiteral(let s):
      
      if wrap {
        output("One(.anyOf(\(s._quoted)))")
      } else {
        output(".anyOf(\(s._quoted))")
      }
      
    case .trivia(_):
      // We never print trivia
      break
      
    case .intersection(let first, let second):
      if wrap, first.isSimplePrint {
        indent()
        output("One(")
      }
      
      printAsPattern(first, wrap: false)
      printIndented { printer in
        printer.indent()
        printer.output(".intersection(")
        printer.printAsPattern(second, wrap: false, terminateLine: false)
        printer.output(")")
      }
      
      if wrap, first.isSimplePrint {
        output(")")
      }
      
    case .subtraction(let first, let second):
      if wrap, first.isSimplePrint {
        indent()
        output("One(")
      }
      
      printAsPattern(first, wrap: false)
      printIndented { printer in
        printer.indent()
        printer.output(".subtracting(")
        printer.printAsPattern(second, wrap: false, terminateLine: false)
        printer.output(")")
      }
      
      if wrap, first.isSimplePrint {
        output(")")
      }
      
    case .symmetricDifference(let first, let second):
      if wrap, first.isSimplePrint {
        indent()
        output("One(")
      }
      
      printAsPattern(first, wrap: false)
      printIndented { printer in
        printer.indent()
        printer.output(".symmetricDifference(")
        printer.printAsPattern(second, wrap: false, terminateLine: false)
        printer.output(")")
      }
      
      if wrap, first.isSimplePrint {
        output(")")
      }
    }
  }
  
  mutating func printAsRegex(
    _ ccc: DSLTree.CustomCharacterClass,
    asFullRegex: Bool = true,
    terminateLine: Bool = true
  ) {
    indent()
    
    if asFullRegex {
      output("#/")
    }
    
    output("[")
    
    if ccc.isInverted {
      output("^")
    }
    
    for member in ccc.members {
      printAsRegex(member)
    }
    
    output("]")
    
    if asFullRegex {
      if terminateLine {
        print("/#")
      } else {
        output("/#")
      }
    }
  }
  
  mutating func printAsRegex(_ member: DSLTree.CustomCharacterClass.Member) {
    switch member {
    case let .custom(ccc):
      printAsRegex(ccc, terminateLine: false)
      
    case let .range(lhs, rhs):
      output(lhs._regexBase)
      output("-")
      output(rhs._regexBase)
      
    case let .atom(a):
      switch a {
      case let .char(c):
        output(String(c))
      case let .unconverted(a):
        output(a.ast._regexBase)
      default:
        print(" // TODO: Atom \(a)")
      }
      
    case .quotedLiteral(let s):
      output("\\Q\(s)\\E")
      
    case .trivia(_):
      // We never print trivia
      break
      
    case .intersection(let first, let second):
      printAsRegex(first, asFullRegex: false, terminateLine: false)
      output("&&")
      printAsRegex(second, asFullRegex: false, terminateLine: false)
      
    case .subtraction(let first, let second):
      printAsRegex(first, asFullRegex: false, terminateLine: false)
      output("--")
      printAsRegex(second, asFullRegex: false, terminateLine: false)
      
    case .symmetricDifference(let first, let second):
      printAsRegex(first, asFullRegex: false, terminateLine: false)
      output("~~")
      printAsRegex(second, asFullRegex: false, terminateLine: false)
    }
  }
}

extension String {
  // TODO: Escaping?
  fileprivate var _quoted: String {
    "\"\(self._replacing(#"\"#, with: #"\\"#)._replacing(#"""#, with: #"\""#))\""
  }
}

extension AST.Atom.AssertionKind {
  // TODO: Some way to integrate this with conversion...
  var _patternBase: String {
    switch self {
    case .startOfLine:
      return "Anchor.startOfLine"
    case .endOfLine:
      return "Anchor.endOfLine"
    case .wordBoundary:
      return "Anchor.wordBoundary"
    case .notWordBoundary:
      return "Anchor.wordBoundary.inverted"
    case .startOfSubject:
      return "Anchor.startOfSubject"
    case .endOfSubject:
      return "Anchor.endOfSubject"
    case .endOfSubjectBeforeNewline:
      return "Anchor.endOfSubjectBeforeNewline"
    case .textSegment:
      return "Anchor.textSegmentBoundary"
    case .notTextSegment:
      return "Anchor.textSegmentBoundary.inverted"
    case .firstMatchingPositionInSubject:
      return "Anchor.firstMatchingPositionInSubject"
      
    case .resetStartOfMatch:
      return "TODO: Assertion resetStartOfMatch"
    }
  }
}

extension AST.Atom.CharacterProperty {
  var isUnprintableProperty: Bool {
    switch kind {
    case .ascii:
      return true
    case .binary(let b, value: _):
      return isUnprintableBinary(b)
    case .generalCategory(let gc):
      return isUnprintableGeneralCategory(gc)
    case .posix(let p):
      return isUnprintablePOSIX(p)
    case .script(_), .scriptExtension(_):
      return true
    default:
      return false
    }
  }
  
  func isUnprintableBinary(_ binary: Unicode.BinaryProperty) -> Bool {
    // List out the ones we can print because that list is smaller.
    switch binary {
    case .whitespace:
      return false
    default:
      return true
    }
  }
  
  func isUnprintableGeneralCategory(
    _ gc: Unicode.ExtendedGeneralCategory
  ) -> Bool {
    // List out the ones we can print because that list is smaller.
    switch gc {
    case .decimalNumber:
      return false
    default:
      return true
    }
  }
  
  func isUnprintablePOSIX(_ posix: Unicode.POSIXProperty) -> Bool {
    // List out the ones we can print because that list is smaller.
    switch posix {
    case .xdigit:
      return false
    case .word:
      return false
    default:
      return true
    }
  }
}

extension AST.Atom.CharacterProperty {
  // TODO: Some way to integrate this with conversion...
  var _patternBase: String {
    if isUnprintableProperty {
      return _regexBase
    }
    
    return _dslBase
  }
  
  var _dslBase: String {
    switch kind {
    case .binary(let bp, _):
      switch bp {
      case .whitespace:
        return ".whitespace"
      default:
        return ""
      }
      
    case .generalCategory(let gc):
      switch gc {
      case .decimalNumber:
        return ".digit"
      default:
        return ""
      }
      
    case .posix(let p):
      switch p {
      case .xdigit:
        return ".hexDigit"
      case .word:
        return ".word"
      default:
        return ""
      }
      
    default:
      return ""
    }
  }
  
  var _regexBase: String {
    switch kind {
    case .ascii:
      return "[:\(isInverted ? "^" : "")ascii:]"
      
    case .binary(let b, value: _):
      if isInverted {
        return "[^\\p{\(b.rawValue)}]"
      } else {
        return "\\p{\(b.rawValue)}"
      }
      
    case .generalCategory(let gc):
      if isInverted {
        return "[^\\p{\(gc.rawValue)}]"
      } else {
        return "\\p{\(gc.rawValue)}"
      }
      
    case .posix(let p):
      return "[:\(isInverted ? "^" : "")\(p.rawValue):]"
      
    case .script(let s):
      return "[:\(isInverted ? "^" : "")script=\(s.rawValue):]"
      
    case .scriptExtension(let s):
      return "[:\(isInverted ? "^" : "")scx=\(s.rawValue):]"
      
    default:
      return " // TODO: Property \(self)"
    }
  }
}

extension AST.Atom {
  var isUnprintableAtom: Bool {
    switch kind {
    case .keyboardControl, .keyboardMeta, .keyboardMetaControl:
      return true
    case .namedCharacter(_):
      return true
    case .property(let p):
      return p.isUnprintableProperty
    default:
      return false
    }
  }
}

extension AST.Atom {
  /// Base string to use when rendering as a component in a
  /// pattern. Note that when the atom is rendered individually,
  /// it still may need to be wrapped in quotes.
  ///
  /// TODO: We want to coalesce adjacent atoms, likely in
  /// caller, but we might want to be parameterized at that point.
  ///
  /// TODO: Some way to integrate this with conversion...
  var _patternBase: (String, canBeWrapped: Bool) {
    if let anchor = self.assertionKind {
      return (anchor._patternBase, false)
    }

    if isUnprintableAtom {
      return (_regexBase, false)
    }
    
    return _dslBase
  }
  
  var _dslBase: (String, canBeWrapped: Bool) {
    func scalarLiteral(_ s: UnicodeScalar) -> String {
      let hex = String(s.value, radix: 16, uppercase: true)
      return "\\u{\(hex)}"
    }
    switch kind {
    case let .char(c):
      return (String(c), false)

    case let .scalar(s):
      return (scalarLiteral(s.value), false)

    case let .scalarSequence(seq):
      return (seq.scalarValues.map(scalarLiteral).joined(), false)

    case let .property(p):
      return (p._dslBase, true)
      
    case let .escaped(e):
      switch e {
      // Anchors
      case .wordBoundary:
        return ("Anchor.wordBoundary", false)
      case .notWordBoundary:
        return ("Anchor.wordBoundary.inverted", false)
      case .startOfSubject:
        return ("Anchor.startOfSubject", false)
      case .endOfSubject:
        return ("Anchor.endOfSubject", false)
      case .endOfSubjectBeforeNewline:
        return ("Anchor.endOfSubjectBeforeNewline", false)
      case .firstMatchingPositionInSubject:
        return ("Anchor.firstMatchingPositionInSubject", false)
      case .textSegment:
        return ("Anchor.textSegmentBoundary", false)
      case .notTextSegment:
        return ("Anchor.textSegmentBoundary.inverted", false)
        
      // Character Classes
      case .decimalDigit:
        return (".digit", true)
      case .notDecimalDigit:
        return (".digit.inverted", true)
      case .horizontalWhitespace:
        return (".horizontalWhitespace", true)
      case .notHorizontalWhitespace:
        return (".horizontalWhitespace.inverted", true)
      case .whitespace:
        return (".whitespace", true)
      case .notWhitespace:
        return (".whitespace.inverted", true)
      case .wordCharacter:
        return (".word", true)
      case .notWordCharacter:
        return (".word.inverted", true)
      case .graphemeCluster:
        return (".anyGraphemeCluster", true)
      case .newlineSequence:
        return (".newlineSequence", true)
      case .notNewline:
        return (".newlineSequence.inverted", true)
      case .verticalTab:
        return (".verticalWhitespace", true)
      case .notVerticalTab:
        return (".verticalWhitespace.inverted", true)
        
      // Literal single characters all get converted into DSLTree.Atom.scalar
        
      default:
        return ("TODO: escaped \(e)", false)
      }
      
    case .namedCharacter:
      return (" /* TODO: named character */", false)

    case .any:
      return (".any", true)

    case .startOfLine, .endOfLine:
      fatalError("unreachable")

    case .backreference:
      return (" /* TODO: back reference */", false)

    case .subpattern:
      return (" /* TODO: subpattern */", false)

    case .callout:
      return (" /* TODO: callout */", false)

    case .backtrackingDirective:
      return (" /* TODO: backtracking directive */", false)

    case .changeMatchingOptions:
      return ("/* TODO: change matching options */", false)
      
    // Every other case we've already decided cannot be represented inside the
    // DSL.
    default:
      return ("", false)
    }
  }
  
  var _regexBase: String {
    switch kind {
    case .char, .scalar, .scalarSequence:
      return literalStringValue!

    case let .property(p):
      return p._regexBase
      
    case let .escaped(e):
      return "\\\(e.character)"
      
    case .keyboardControl(let k):
      return "\\c\(k)"
      
    case .keyboardMeta(let k):
      return "\\M-\(k)"
      
    case .keyboardMetaControl(let k):
      return "\\M-\\C-\(k)"
      
    case .namedCharacter(let n):
      return "\\N{\(n)}"
      
    case .any:
      return "."
      
    case .startOfLine, .endOfLine:
      fatalError("unreachable")
      
    case .backreference:
      return " /* TODO: back reference */"
      
    case .subpattern:
      return " /* TODO: subpattern */"
      
    case .callout:
      return " /* TODO: callout */"
      
    case .backtrackingDirective:
      return " /* TODO: backtracking directive */"
      
    case .changeMatchingOptions:
      return "/* TODO: change matching options */"
    }
  }
}

extension AST.Quantification.Amount {
  var _patternBase: String {
    switch self {
    case .zeroOrMore: return "ZeroOrMore"
    case .oneOrMore:  return "OneOrMore"
    case .zeroOrOne:  return "Optionally"
    case let .exactly(n):  return "Repeat(count: \(n.value))"
    case let .nOrMore(n):  return "Repeat(\(n.value)...)"
    case let .upToN(n):    return "Repeat(...\(n.value))"
    case let .range(n, m): return "Repeat(\(n.value)...\(m.value))"
    }
  }
}

extension AST.Quantification.Kind {
  var _patternBase: String {
    switch self {
    case .eager: return ".eager"
    case .reluctant: return ".reluctant"
    case .possessive: return ".possessive"
    }
  }
}

extension DSLTree.QuantificationKind {
  var _patternBase: String {
    (ast ?? .eager)._patternBase
  }
}

extension DSLTree.CustomCharacterClass.Member {
  var isUnprintableMember: Bool {
    switch self {
    case .atom(.unconverted(let a)):
      return a.ast.isUnprintableAtom
    case .custom(let c):
      return c.hasUnprintableProperty
    case .range(.unconverted(let lhs), .unconverted(let rhs)):
      return lhs.ast.isUnprintableAtom || rhs.ast.isQuantifiable
    case .intersection(let first, let second):
      return first.hasUnprintableProperty || second.hasUnprintableProperty
    case .subtraction(let first, let second):
      return first.hasUnprintableProperty || second.hasUnprintableProperty
    case .symmetricDifference(let first, let second):
      return first.hasUnprintableProperty || second.hasUnprintableProperty
    default:
      return false
    }
  }
}

extension DSLTree.CustomCharacterClass {
  var hasUnprintableProperty: Bool {
    members.contains {
      $0.isUnprintableMember
    }
  }
  
  var isSimplePrint: Bool {
    if members.count == 1 {
      switch members[0] {
      case .intersection(_, _):
        return false
      case .subtraction(_, _):
        return false
      case .symmetricDifference(_, _):
        return false
      default:
        return true
      }
    }
    
    let nonCharMembers = members.filter {
      switch $0 {
      case let .atom(a):
        switch a {
        case .char(_):
          return false
        case .scalar(_):
          return false
        case .unconverted(_):
          return true
        default:
          return true
        }
        
      case .quotedLiteral(_):
        return false
        
      case .trivia(_):
        return false
        
      default:
        return true
      }
    }
    
    if nonCharMembers.isEmpty {
      return true
    }
    
    return false
  }
}

extension DSLTree.Atom {
  func _patternBase(_ printer: inout PrettyPrinter) -> String? {
    switch self {
    case .any:
      return ".any"
      
    case let .char(c):
      return String(c)._quoted
      
    case let .scalar(s):
      let hex = String(s.value, radix: 16, uppercase: true)
      return "\\u{\(hex)}"._quoted
      
    case let .unconverted(a):
      if a.ast.isUnprintableAtom {
        return "#/\(a.ast._regexBase)/#"
      } else {
        return a.ast._dslBase.0
      }
      
    case .assertion(let a):
      return a.ast._patternBase
      
    case .backreference(_):
      return "/* TOOD: backreferences */"
      
    case .symbolicReference:
      return "/* TOOD: symbolic references */"
      
    case .changeMatchingOptions(let matchingOptions):
      for add in matchingOptions.ast.adding {
        switch add.kind {
        case .reluctantByDefault:
          printer.quantificationBehavior = .reluctant
        default:
          break
        }
      }
    }
    
    return nil
  }
  
  var _regexBase: String {
    switch self {
    case .any:
      return "."
      
    case let .char(c):
      return String(c)
      
    case let .scalar(s):
      let hex = String(s.value, radix: 16, uppercase: true)
      return "\\u{\(hex)}"._quoted
      
    case let .unconverted(a):
      return a.ast._regexBase
      
    case .assertion:
      return "/* TODO: assertions */"
    case .backreference:
      return "/* TOOD: backreferences */"
    case .symbolicReference:
      return "/* TOOD: symbolic references */"
    case .changeMatchingOptions(let matchingOptions):
      var result = ""
      
      for add in matchingOptions.ast.adding {
        switch add.kind {
        case .reluctantByDefault:
          result += "(?U)"
        default:
          break
        }
      }
      
      return result
    }
  }
}

extension DSLTree.Node {
  func getNamedCaptures() -> [String] {
    var result: [String] = []
    
    switch self {
    case .capture(let name, _, _):
      if let name = name {
        result.append(name)
      }
      
    case .concatenation(let nodes):
      for node in nodes {
        result += node.getNamedCaptures()
      }
      
    case .convertedRegexLiteral(let node, _):
      result += node.getNamedCaptures()
      
    case .quantification(_, _, let node):
      result += node.getNamedCaptures()
      
    default:
      break
    }
    
    return result
  }
}
