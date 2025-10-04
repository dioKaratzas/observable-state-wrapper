//===----------------------------------------------------------------------===//
//
// This source file is part of the ObservableStateWrapper open source project
//
// Copyright (c) Dionysios Karatzas
// Licensed under the MIT license
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

/// Adopt this protocol on wrapper types that want to interoperate with
/// ``ObservableStateWrapper`` while keeping control of their own storage.
///
/// Conforming wrappers are responsible for constructing a wrapper instance from
/// the property's value and returning the stored value on access.
/// The macro will call your factory in all accessors (`init/get/set/_modify`).
///
/// Example
/// ```swift
/// @propertyWrapper
/// public struct Box<T> { var ref: Ref<T>; public var wrappedValue: T }
///
/// extension Box: ObservableWrapper {
///   public typealias WrappedValue = T
///   public static func makeWrapper(from value: T, config: ()) -> Self { .init(wrappedValue: value) }
/// }
/// ```
public protocol ObservableWrapper<WrappedValue> {
    associatedtype WrappedValue
    associatedtype Config = Void

    /// Builds a wrapper instance from the property's value and a strongly-typed configuration.
    static func makeWrapper(from value: WrappedValue, config: Config) -> Self
}

public extension ObservableWrapper where Config == Void {
    /// Convenience factory for wrappers that do not require configuration.
    ///
    /// The macro prefers this overload when your `Config` is `Void`.
    static func makeWrapper(from value: WrappedValue) -> Self { makeWrapper(from: value, config: ()) }
}
