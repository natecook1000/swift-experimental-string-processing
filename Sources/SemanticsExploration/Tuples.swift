public struct Tuple2<__0, __1> {
  public var value: (__0, __1)
  
  public var _0: __0 {
    get { value.0 }
    set { value.0 = newValue }
  }
  public var _1: __1 {
    get { value.1 }
    set { value.1 = newValue }
  }
}

public struct Tuple3<__0, __1, __2> {
  public var value: (__0, __1, __2)
  
  public var _0: __0 {
    get { value.0 }
    set { value.0 = newValue }
  }
  public var _1: __1 {
    get { value.1 }
    set { value.1 = newValue }
  }
  public var _2: __2 {
    get { value.2 }
    set { value.2 = newValue }
  }
}

extension Tuple3 {
  init(_0: __0, _1: __1, _2: __2) {
    value = (_0, _1, _2)
  }
}
