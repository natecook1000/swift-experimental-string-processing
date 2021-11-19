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
}

