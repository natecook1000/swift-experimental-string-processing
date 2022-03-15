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

import _MatchingEngine

public struct Anchor {
  internal enum Kind {
    case startOfSubject
    case endOfSubjectBeforeNewline
    case endOfSubject
    case firstMatchingPositionInSubject
    case textSegmentBoundary
    case startOfLine
    case endOfLine
    case wordBoundary
  }
  
  var kind: Kind
  var isInverted: Bool = false
}

extension Anchor: RegexProtocol {
  var astAssertion: AST.Atom.AssertionKind {
    if !isInverted {
      switch kind {
      case .startOfSubject: return .startOfSubject
      case .endOfSubjectBeforeNewline: return .endOfSubjectBeforeNewline
      case .endOfSubject: return .endOfSubject
      case .firstMatchingPositionInSubject: return .firstMatchingPositionInSubject
      case .textSegmentBoundary: return .textSegment
      case .startOfLine: return .startOfLine
      case .endOfLine: return .endOfLine
      case .wordBoundary: return .wordBoundary
      }
    } else {
      switch kind {
      case .startOfSubject: fatalError("Not yet supported")
      case .endOfSubjectBeforeNewline: fatalError("Not yet supported")
      case .endOfSubject: fatalError("Not yet supported")
      case .firstMatchingPositionInSubject: fatalError("Not yet supported")
      case .textSegmentBoundary: return .notTextSegment
      case .startOfLine: fatalError("Not yet supported")
      case .endOfLine: fatalError("Not yet supported")
      case .wordBoundary: return .notWordBoundary
      }
    }
  }
  
  public var regex: Regex<Substring> {
    Regex(node: .atom(.assertion(astAssertion)))
  }
}

// MARK: - Public API

extension Anchor {
  /// Matches at the very start of the input string.
  public static var startOfSubject: Anchor {
    Anchor(kind: .startOfSubject)
  }
  
  /// Matches at the very end of the input string, or before a newline at the
  /// very end of the input string.
  public static var endOfSubjectBeforeNewline: Anchor {
    Anchor(kind: .endOfSubjectBeforeNewline)
  }

  /// Matches at the very end of the input string.
  public static var endOfSubject: Anchor {
    Anchor(kind: .endOfSubject)
  }

  // TODO: Are we supporting this?
//  public static var resetStartOfMatch: Anchor {
//    Anchor(kind: resetStartOfMatch)
//  }

  public static var firstMatchingPositionInSubject: Anchor {
    Anchor(kind: .firstMatchingPositionInSubject)
  }

  /// Matches a position that is on a grapheme segment boundary.
  public static var textSegmentBoundary: Anchor {
    Anchor(kind: .textSegmentBoundary)
  }
  
  /// Matches at the start of a line.
  public static var startOfLine: Anchor {
    Anchor(kind: .startOfLine)
  }

  /// Matches at the end of a line.
  public static var endOfLine: Anchor {
    Anchor(kind: .endOfLine)
  }

  /// Matches a position between a word character and a non-word character.
  public static var wordBoundary: Anchor {
    Anchor(kind: .wordBoundary)
  }
  
  public var inverted: Anchor {
    var result = self
    result.isInverted.toggle()
    return result
  }
}

public func lookahead<R: RegexProtocol>(
  negative: Bool = false,
  @RegexBuilder _ content: () -> R
) -> Regex<R.Match> {
  Regex(node: .group(negative ? .negativeLookahead : .lookahead, content().regex.root))
}
  
public func lookahead<R: RegexProtocol>(
  _ component: R,
  negative: Bool = false
) -> Regex<R.Match> {
  Regex(node: .group(negative ? .negativeLookahead : .lookahead, component.regex.root))
}
