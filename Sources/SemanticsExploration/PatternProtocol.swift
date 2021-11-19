public protocol PatternProtocol {
  associatedtype MatchResult
    
  func firstMatch(for str: String, from i: String.Index)
    -> (result: MatchResult, range: Range<String.Index>)?
}

extension String {
  public func firstMatch<R: PatternProtocol>(of regex: R) -> R.MatchResult? {
    return regex.firstMatch(for: self, from: startIndex)?.0
  }
}

