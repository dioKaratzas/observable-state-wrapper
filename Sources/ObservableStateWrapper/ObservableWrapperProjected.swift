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

/// Optional refinement for wrappers that can expose a projected value ($property).
///
/// Adopt this when your wrapper has a natural projection you want the macro to
/// surface via a `$name` peer (e.g., `PresentationState<State>`). When you use
/// `@ObservableStateWrapper(..., projected: true)`, the macro emits a projected peer of
/// type `StorageType.Projected` and reads/writes through `storage.projectedValue`.
public protocol ObservableWrapperProjected<WrappedValue>: ObservableWrapper {
    associatedtype ProjectedValue
}
