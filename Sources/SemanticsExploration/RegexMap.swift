public struct RegexMap<R: PatternProtocol, MatchResult>
  where R.MatchResult: RegexMatchResultProtocol
{
  var regex: R
  var transform: (R.MatchResult.AllCaptures) -> MatchResult
}

extension RegexMap: PatternProtocol {
  public func firstMatch(for str: String, from i: String.Index)
    -> (result: MatchResult, range: Range<String.Index>)?
  {
    guard let baseResult = regex.firstMatch(for: str, from: i) else {
      return nil
    }
    return (transform(baseResult.result.allCaptures), baseResult.range)
  }
}

public struct RegexValidatingMap<R: PatternProtocol, MatchResult>
  where R.MatchResult: RegexMatchResultProtocol
{
  var regex: R
  var transform: (R.MatchResult.AllCaptures) -> MatchResult?
}

extension RegexValidatingMap: PatternProtocol {
  public func firstMatch(for str: String, from i: String.Index)
    -> (result: MatchResult, range: Range<String.Index>)?
  {
    var start = i
    while true {
      guard let baseResult = regex.firstMatch(for: str, from: start) else {
        return nil
      }
      if let transformed = transform(baseResult.result.allCaptures) {
        return (transformed, baseResult.range)
      }
      
      start = baseResult.range.upperBound
      if baseResult.range.isEmpty {
        if start == str.endIndex {
          return nil
        }
        str.formIndex(after: &start)
      }
    }
  }
}

extension PatternProtocol where MatchResult: RegexMatchResultProtocol {
  /// Returns a pattern that transforms the match result of this regular
  /// expression, using the given closure.
  ///
  /// For example, this code creates a regular expression that matches exactly
  /// two hexadecimal digits, then maps that result to a `UInt8` value.
  ///
  ///     let hexDigitPattern = /[0-9A-F]{2}/
  ///     let bytePattern = hexDigitPattern.map { UInt8($0, radix: 16)! }
  ///     if let firstByte = "Have a byte: 20".firstMatch(of: bytePattern) {
  ///         print(firstByte)
  ///     }
  ///     // Prints "32"
  public func map<T>(_ transform: @escaping (MatchResult.AllCaptures) -> T)
    -> RegexMap<Self, T> {
    RegexMap(regex: self, transform: transform)
  }
  
  /// Returns a pattern that returns the first non-`nil` match result, when
  /// transformed by the given closure.
  ///
  /// For example, this code creates a regular expression that matches any group
  /// of lowercase letters, then maps that result to only allow matches that are
  /// in ascending order.
  ///
  ///     let wordPattern = /[a-z]+/
  ///     let alphabetizedWordPattern = wordPattern.validatingMap { match in
  ///         match.isSorted() ? match : nil
  ///     }
  ///     let str = "Do you know any alphabetized words?"
  ///     if let word = str.firstMatch(of: alphabetizedWordPattern) {
  ///         print(word)
  ///     }
  ///     // Prints "know"
  public func validatingMap<T>(_ transform: @escaping (MatchResult.AllCaptures) -> T?)
    -> RegexValidatingMap<Self, T> {
    RegexValidatingMap(regex: self, transform: transform)
  }
}

