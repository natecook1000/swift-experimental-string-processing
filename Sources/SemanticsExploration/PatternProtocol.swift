public protocol PatternProtocol {
//  associatedtype Match: RegexMatch
  associatedtype MatchResult
  
  // Fake requirements for prototyping purposes
  init(_match: AnyRegexMatch)
  var _match: AnyRegexMatch { get }
  
  // Simulates the actual search of a string.
  //
  // This will actually need an index or range, and possibly a Boolean for
  // whether an empty match is allowable at the starting position.
  func _getMatchResult(for str: String) -> MatchResult
}

extension String {
  public func firstMatch<R: PatternProtocol>(of regex: R) -> R.MatchResult? {
    return regex._getMatchResult(for: self)
  }
}

