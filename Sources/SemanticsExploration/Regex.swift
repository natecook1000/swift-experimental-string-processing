public protocol RegexPatternProtocol: PatternProtocol
  where MatchResult: RegexMatchResultProtocol
{
  associatedtype Match: RegexMatch
}

public protocol RegexMatchResultProtocol {
  associatedtype Match: RegexMatch
  associatedtype AllCaptures
  associatedtype FullMatch
  
  /// A destructured version of the captures, bound to the correct type.
  var allCaptures: AllCaptures { get }
  
  /// The entire matched substring, bound to the correct type.
  var fullMatch: FullMatch { get }
  
  /// The entire matched range.
  var fullRange: Match.InitialMember.BoundToRange { get }
}

public struct Regex<Match: RegexMatch>: RegexPatternProtocol {
  public let _match: AnyRegexMatch
  
  public func _getMatchResult(for str: String) -> MatchResult {
    MatchResult(_string: str, _match: _match)
  }
  
  public init(_match: AnyRegexMatch) {
    self._match = _match
  }
  
  @dynamicMemberLookup
  public struct MatchResult: RegexMatchResultProtocol {
    let _string: String
    let _match: Match

    init(_string: String, _match: AnyRegexMatch) {
      self._string = _string
      self._match = Match(_match)
    }
    
    public var fullMatch: Match.InitialMember.BoundToString {
      _match.initialMember.bound(to: _string)
    }
    
    public var fullRange: Match.InitialMember.BoundToRange {
      _match.initialMember.boundToRange()
    }
    
    public var allCaptures: Match.BoundToString {
      _match.bound(to: _string)
    }

    public subscript<T: RegexMatch>(dynamicMember keyPath: KeyPath<Match, T>) -> T.BoundToString {
      _match[keyPath: keyPath].bound(to: _string)
    }

    @dynamicMemberLookup
    public struct Ranges {
      let _match: Match

      public subscript<T: RegexMatch>(dynamicMember keyPath: KeyPath<Match, T>) -> T.BoundToRange {
        _match[keyPath: keyPath].boundToRange()
      }
    }

    public var ranges: Ranges {
      Ranges(_match: _match)
    }
  }
}

public struct UTF8Regex<Match: RegexMatch>: RegexPatternProtocol {
  public let _match: AnyRegexMatch
  
  public func _getMatchResult(for str: String) -> MatchResult {
    MatchResult(_string: str, _match: _match)
  }
  
  public init(_match: AnyRegexMatch) {
    self._match = _match
  }
  
  @dynamicMemberLookup
  public struct MatchResult: RegexMatchResultProtocol {
    let _string: String
    let _match: Match

    init(_string: String, _match: AnyRegexMatch) {
      self._string = _string
      self._match = Match(_match)
    }
    
    public var fullMatch: Match.InitialMember.BoundToUTF8View {
      _match.initialMember.bound(to: _string.utf8)
    }
    
    public var fullRange: Match.InitialMember.BoundToRange {
      _match.initialMember.boundToRange()
    }
    
    public var allCaptures: Match.BoundToUTF8View {
      _match.bound(to: _string.utf8)
    }

    public subscript<T: RegexMatch>(dynamicMember keyPath: KeyPath<Match, T>) -> T.BoundToUTF8View {
      _match[keyPath: keyPath].bound(to: _string.utf8)
    }

    @dynamicMemberLookup
    public struct Ranges {
      let _match: Match

      public subscript<T: RegexMatch>(dynamicMember keyPath: KeyPath<Match, T>) -> T.BoundToRange {
        _match[keyPath: keyPath].boundToRange()
      }
    }

    public var ranges: Ranges {
      Ranges(_match: _match)
    }
  }
}

// TODO: Should these be on this protocol? Or should they just be on the
// concrete types, instead?
extension RegexPatternProtocol {
  public var utf8Semantics: UTF8Regex<Match> {
    UTF8Regex(_match: _match)
  }
  
  public var unicodeSemantics: Regex<Match> {
    Regex(_match: _match)
  }
}
