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

/// ObservableStateWrapper is an attached Swift macro for TCA's `@ObservableState` that lets you
/// use a custom `@propertyWrapper` as the storage of an observable property without losing
/// observation correctness.
///
/// The macro expands a computed property that delegates storage to your wrapper type and wires up
/// `init/get/set/_modify` to TCA's observation registrar.
///
/// Generated members
/// - Accessors (`init/get/set/_modify`) that record reads and notify writes via the registrar
/// - A private backing storage peer (e.g. `_value: Wrapper<T>`) initialized via `Wrapper.makeWrapper`
/// - Optionally, a projected peer (`$value`) that forwards to the wrapper's `projectedValue`
///
/// Usage
/// - Apply inside `@ObservableState` and mark the property `@ObservationStateIgnored` to prevent
///   TCA from also synthesizing accessors.
/// - If the property is non‑optional and has no inline initializer, the backing storage is left
///   uninitialized so you can set it in your initializer using `Wrapper.makeWrapper(from:)`.
/// - Implicitly unwrapped optionals (e.g. `String!`) are treated like optionals.
///
/// Example
/// ```swift
/// @ObservableState
/// struct State {
///   @ObservableStateWrapper(Clamped<Int>.self, config: 0 ... 100)
///   @ObservationStateIgnored
///   var percent: Int = 150
/// }
/// ```
///
/// - Parameters:
///   - wrapper: The wrapper type, passed as `Wrapper<T>.self`. The wrapper must conform to
///     ``ObservableWrapper`` for the property's value type `T`.
///   - configuration: Optional, positional configuration values forwarded to your wrapper
///     factory. Prefer the labeled `config:` variant for a strongly‑typed configuration channel.
@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_))
public macro ObservableStateWrapper(_ wrapper: Any, _ configuration: Any...) = #externalMacro(
    module: "ObservableStateWrapperPlugin",
    type: "ObservableStateWrapper"
)

/// ObservableStateWrapper is an attached Swift macro for TCA's `@ObservableState` that lets you
/// use a custom `@propertyWrapper` as the storage of an observable property without losing
/// observation correctness.
///
/// The macro expands a computed property that delegates storage to your wrapper type and wires up
/// `init/get/set/_modify` to TCA's observation registrar.
///
/// Generated members
/// - Accessors (`init/get/set/_modify`) that record reads and notify writes via the registrar
/// - A private backing storage peer (e.g. `_value: Wrapper<T>`) initialized via `Wrapper.makeWrapper`
/// - Optionally, a projected peer (`$value`) that forwards to the wrapper's `projectedValue`
///
/// Usage
/// - Apply inside `@ObservableState` and mark the property `@ObservationStateIgnored` to prevent
///   TCA from also synthesizing accessors.
/// - If the property is non‑optional and has no inline initializer, the backing storage is left
///   uninitialized so you can set it in your initializer using `Wrapper.makeWrapper(from:)`.
/// - Implicitly unwrapped optionals (e.g. `String!`) are treated like optionals.
///
/// Example
/// ```swift
/// @ObservableState
/// struct State {
///   @ObservableStateWrapper(Clamped<Int>.self, config: 0 ... 100)
///   @ObservationStateIgnored var percent: Int = 150
/// }
/// ```
///
/// - Parameters:
///   - wrapper: The wrapper type, as `Wrapper<T>.self`.
///   - config: A value of the wrapper's `Config` type used when constructing the backing storage
///     and when re‑wrapping in accessors.
@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_))
public macro ObservableStateWrapper(_ wrapper: Any, config: Any) = #externalMacro(
    module: "ObservableStateWrapperPlugin",
    type: "ObservableStateWrapper"
)

/// ObservableStateWrapper is an attached Swift macro for TCA's `@ObservableState` that lets you
/// use a custom `@propertyWrapper` as the storage of an observable property without losing
/// observation correctness.
///
/// The macro expands a computed property that delegates storage to your wrapper type and wires up
/// `init/get/set/_modify` to TCA's observation registrar.
///
/// Generated members
/// - Accessors (`init/get/set/_modify`) that record reads and notify writes via the registrar
/// - A private backing storage peer (e.g. `_value: Wrapper<T>`) initialized via `Wrapper.makeWrapper`
/// - When `projected` is `true`, a projected peer (`$value`) that forwards to the wrapper's `projectedValue`
///
/// Usage
/// - Apply inside `@ObservableState` and mark the property `@ObservationStateIgnored` to prevent
///   TCA from also synthesizing accessors.
/// - If the property is non‑optional and has no inline initializer, the backing storage is left
///   uninitialized so you can set it in your initializer using `Wrapper.makeWrapper(from:)`.
/// - Implicitly unwrapped optionals (e.g. `String!`) are treated like optionals.
///
/// Example
/// ```swift
/// @ObservableState
/// struct State {
///   @ObservableStateWrapper(PresentationState<AlertState<Action>>.self, projected: true)
///   @ObservationStateIgnored var alert: AlertState<Action>?
/// }
/// ```
///
/// - Important: Your wrapper must expose a `projectedValue` and an associated
///   `ProjectedValue` type. Adopt ``ObservableWrapperProjected`` to document this contract.
///
/// - Parameters:
///   - wrapper: The wrapper type, as `Wrapper<T>.self`.
///   - projected: When `true`, generate `$property` that forwards to `storage.projectedValue`.
@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_), prefixed(`$`))
public macro ObservableStateWrapper(_ wrapper: Any, projected: Bool) = #externalMacro(
    module: "ObservableStateWrapperPlugin",
    type: "ObservableStateWrapper"
)

/// ObservableStateWrapper is an attached Swift macro for TCA's `@ObservableState` that lets you
/// use a custom `@propertyWrapper` as the storage of an observable property without losing
/// observation correctness.
///
/// The macro expands a computed property that delegates storage to your wrapper type and wires up
/// `init/get/set/_modify` to TCA's observation registrar.
///
/// Generated members
/// - Accessors (`init/get/set/_modify`) that record reads and notify writes via the registrar
/// - A private backing storage peer (e.g. `_value: Wrapper<T>`) initialized via `Wrapper.makeWrapper`
/// - When `projected` is `true`, a projected peer (`$value`) that forwards to the wrapper's `projectedValue`
///
/// Usage
/// - Apply inside `@ObservableState` and mark the property `@ObservationStateIgnored` to prevent
///   TCA from also synthesizing accessors.
/// - If the property is non‑optional and has no inline initializer, the backing storage is left
///   uninitialized so you can set it in your initializer using `Wrapper.makeWrapper(from:)`.
/// - Implicitly unwrapped optionals (e.g. `String!`) are treated like optionals.
///
/// Example
/// ```swift
/// @ObservableState
/// struct State {
///   @ObservableStateWrapper(Clamped<Int>.self, projected: true, config: 0 ... 10)
///   @ObservationStateIgnored var percent: Int = 3
/// }
/// ```
///
/// - Important: Your wrapper must expose `projectedValue`/`ProjectedValue` to use projection,
///   and conform to ``ObservableWrapper`` with a matching `Config` type to accept `config`.
///
/// - Parameters:
///   - wrapper: The wrapper type, as `Wrapper<T>.self`.
///   - projected: When `true`, generate `$property` forwarding to `storage.projectedValue`.
///   - config: Strongly‑typed configuration forwarded to wrapper construction and re‑wrapping.
@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_), prefixed(`$`))
public macro ObservableStateWrapper(_ wrapper: Any, projected: Bool, config: Any) = #externalMacro(
    module: "ObservableStateWrapperPlugin",
    type: "ObservableStateWrapper"
)
