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

import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct MacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ObservableStateWrapper.self
    ]
}
