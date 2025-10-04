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

@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_))
public macro ObservableStateWrapper(_ wrapper: Any, _ configuration: Any...) = #externalMacro(
    module: "ObservableStateWrapperPlugin",
    type: "ObservableStateWrapper"
)

// Overload that accepts a single, named typed configuration channel.
@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_))
public macro ObservableStateWrapper(_ wrapper: Any, config: Any) = #externalMacro(
    module: "ObservableStateWrapperPlugin",
    type: "ObservableStateWrapper"
)

// Overloads that opt-in to projected value ($prop) synthesis.
@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_), prefixed(`$`))
public macro ObservableStateWrapper(_ wrapper: Any, projected: Bool) = #externalMacro(
    module: "ObservableStateWrapperPlugin",
    type: "ObservableStateWrapper"
)

@attached(accessor, names: named(init), named(get), named(set), named(_modify))
@attached(peer, names: prefixed(_), prefixed(`$`))
public macro ObservableStateWrapper(_ wrapper: Any, projected: Bool, config: Any) = #externalMacro(
    module: "ObservableStateWrapperPlugin",
    type: "ObservableStateWrapper"
)
