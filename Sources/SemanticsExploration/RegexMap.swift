public struct RegexMap<R: PatternProtocol, T>
  where R.MatchResult: RegexMatchResultProtocol
{
  var regex: R
  var transform: (R.MatchResult.AllCaptures) -> T
}

extension RegexMap: PatternProtocol {
  public init(_match: AnyRegexMatch) {
    fatalError()
  }
  public var _match: AnyRegexMatch { fatalError() }
  
  public func _getMatchResult(for str: String) -> T {
    transform(regex._getMatchResult(for: str).allCaptures)
  }
}

extension PatternProtocol where MatchResult: RegexMatchResultProtocol {
  public func mapCaptures<T>(_ transform: @escaping (MatchResult.AllCaptures) -> T)
    -> RegexMap<Self, T> {
    RegexMap(regex: self, transform: transform)
  }
}

