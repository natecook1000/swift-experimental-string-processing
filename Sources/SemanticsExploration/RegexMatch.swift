public protocol RegexMatch {
  associatedtype BoundToRange
  associatedtype BoundToString
  associatedtype BoundToUTF8View

  associatedtype InitialMember: RegexMatch
  
  init(_ match: AnyRegexMatch)

  var initialMember: InitialMember { get }
  func boundToRange() -> BoundToRange
  func bound(to string: String) -> BoundToString
  func bound(to utf8View: String.UTF8View) -> BoundToUTF8View
}

public enum AnyRegexMatch {
  case range(Range<String.Index>)
  indirect case tuple([AnyRegexMatch])
  indirect case optional(AnyRegexMatch?)
  indirect case array([AnyRegexMatch])
}

// bottom placeholder type
public struct Submatch: RegexMatch {
  let range: Range<String.Index>

  public init(_ match: AnyRegexMatch) {
    guard case let .range(r) = match else {
      fatalError()
    }
    range = r
  }

  public var initialMember: Submatch {
    self
  }
  
  public func boundToRange() -> Range<String.Index> {
    range
  }

  public func bound(to string: String) -> Substring {
    string[range]
  }

  public func bound(to utf8View: String.UTF8View)
    -> String.UTF8View.SubSequence
  {
    utf8View[range]
  }
}

extension Optional: RegexMatch where Wrapped: RegexMatch {
  public init(_ match: AnyRegexMatch) {
    guard case let .optional(submatch) = match else {
      fatalError()
    }

    self = submatch.map { Wrapped($0) }
  }

  public var initialMember: Self {
    self
  }
  
  public func boundToRange() -> Wrapped.BoundToRange? {
    map { $0.boundToRange() }
  }

  public func bound(to string: String) -> Wrapped.BoundToString? {
    map { $0.bound(to: string) }
  }

  public func bound(to utf8View: String.UTF8View) -> Wrapped.BoundToUTF8View? {
    map { $0.bound(to: utf8View) }
  }
}

extension Array: RegexMatch where Element: RegexMatch {
  public init(_ match: AnyRegexMatch) {
    guard case let .array(submatches) = match else {
      fatalError()
    }

    self = submatches.map { Element($0) }
  }

  public var initialMember: Element? {
    first
  }
  
  public func boundToRange() -> [Element.BoundToRange] {
    map { $0.boundToRange() }
  }

  public func bound(to string: String) -> [Element.BoundToString] {
    map { $0.bound(to: string) }
  }

  public func bound(to utf8View: String.UTF8View) -> [Element.BoundToUTF8View] {
    map { $0.bound(to: utf8View) }
  }
}

extension Tuple3: RegexMatch where __0: RegexMatch, __1: RegexMatch, __2: RegexMatch {
  public init(_ match: AnyRegexMatch) {
    guard case let .tuple(submatches) = match else {
      fatalError()
    }

    self = .init(
      _0: __0(submatches[0]),
      _1: __1(submatches[1]),
      _2: __2(submatches[2])
    )
  }

  public var initialMember: __0 {
    self._0
  }
  
  public func boundToRange()
    -> Tuple3<__0.BoundToRange, __1.BoundToRange, __2.BoundToRange>
  {
    .init(
      _0: _0.boundToRange(),
      _1: _1.boundToRange(),
      _2: _2.boundToRange()
    )
  }

  public func bound(to string: String)
    -> Tuple3<__0.BoundToString, __1.BoundToString, __2.BoundToString>
  {
    .init(
      _0: _0.bound(to: string),
      _1: _1.bound(to: string),
      _2: _2.bound(to: string)
    )
  }

  public func bound(to utf8View: String.UTF8View)
    -> Tuple3<__0.BoundToUTF8View, __1.BoundToUTF8View, __2.BoundToUTF8View>
  {
    .init(
      _0: _0.bound(to: utf8View),
      _1: _1.bound(to: utf8View),
      _2: _2.bound(to: utf8View)
    )
  }
}
