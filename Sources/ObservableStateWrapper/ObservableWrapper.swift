/// Adopt this protocol on wrapper types that want to interoperate with
/// ``ObservableStateWrapper`` while keeping control of their own storage.
///
/// Conforming wrappers are responsible for constructing a wrapper instance from
/// an optional value and returning the stored value on access.
public protocol ObservableWrapper<WrappedValue> {
    associatedtype WrappedValue
    associatedtype Config = Void

    /// Builds a wrapper instance from an optional value produced by the property
    /// and a strongly-typed configuration.
    static func makeWrapper(from value: WrappedValue, config: Config) -> Self
}

public extension ObservableWrapper where Config == Void {
    /// Convenience factory for wrappers that do not require configuration.
    static func makeWrapper(from value: WrappedValue) -> Self { makeWrapper(from: value, config: ()) }
}
