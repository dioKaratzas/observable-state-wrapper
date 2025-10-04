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

/// Optional refinement for wrappers that expose a projected value (`$property`).
///
/// Adopt this when your wrapper has a natural projection you want the macro to surface
/// via a `$name` peer (e.g., `PresentationState<State>`). When you use
/// `@ObservableStateWrapper(..., projected: true)`, the macro emits a projected peer whose
/// type is `StorageType.ProjectedValue` and whose accessors read/write through
/// `storage.projectedValue`.
///
/// Example
/// ```swift
/// @propertyWrapper
/// struct PresentationState<T> {
///   var wrappedValue: T?
///   var projectedValue: Binding<Bool>
/// }
///
/// extension PresentationState: ObservableWrapperProjected {
///   typealias WrappedValue = T?
///   typealias ProjectedValue = Binding<Bool>
///   static func makeWrapper(from value: T?, config: ()) -> Self { .init(wrappedValue: value, projectedValue: .constant(value != nil)) }
/// }
/// ```
public protocol ObservableWrapperProjected<WrappedValue>: ObservableWrapper {
    associatedtype ProjectedValue
}
