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

import Testing
import MacroTesting
@testable import ObservableStateWrapperPlugin

@Suite(
    .macros(
        [
            "ObservableStateWrapper": ObservableStateWrapper.self
        ]
    )
)
struct ObservableStateWrapperSuite {
    @Test("Generates registrar-instrumented accessors and observed storage")
    func observedWrapperExpansion() {
        assertMacro {
            #"""
            struct FeatureState {
              @ObservableStateWrapper(OmitCoding<Set<EthereumAddress>?>.self)
              @ObservationStateIgnored
              var unresolvedAddresses: Set<EthereumAddress>? = nil
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              @ObservationStateIgnored
              var unresolvedAddresses: Set<EthereumAddress>? {
                @storageRestrictions(initializes: _unresolvedAddresses)
                init(initialValue) {
                  _unresolvedAddresses = OmitCoding<Set<EthereumAddress>?>.makeWrapper(from: initialValue)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.unresolvedAddresses)
                  return _unresolvedAddresses.wrappedValue
                }
                set {
                  let newWrapper = type(of: _unresolvedAddresses).makeWrapper(from: newValue)
                  _$observationRegistrar.mutate(self, keyPath: \\.unresolvedAddresses, &_unresolvedAddresses, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _unresolvedAddresses.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.unresolvedAddresses, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.unresolvedAddresses, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _unresolvedAddresses).makeWrapper(from: value)
                    _unresolvedAddresses = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _unresolvedAddresses: OmitCoding<Set<EthereumAddress>?> = OmitCoding<Set<EthereumAddress>?>.makeWrapper(from: nil)
            }
            """
        }
    }

    @Test("Generates projected peer when requested")
    func observedWrapperProjectedPeer() {
        assertMacro {
            #"""
            struct FeatureState {
              @ObservableStateWrapper(Box<String>.self, projected: true)
              @ObservationStateIgnored
              var title: String! = "Hello"
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              @ObservationStateIgnored
              var title: String! {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box<String>.makeWrapper(from: initialValue)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.title)
                  return _title.wrappedValue
                }
                set {
                  let newWrapper = type(of: _title).makeWrapper(from: newValue)
                  _$observationRegistrar.mutate(self, keyPath: \\.title, &_title, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _title.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.title, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.title, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _title).makeWrapper(from: value)
                    _title = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _title: Box<String> = Box<String>.makeWrapper(from: "Hello")

              var $title: Box<String>.ProjectedValue {
                get {
                  _$observationRegistrar.access(self, keyPath: \\.title)
                  return _title.projectedValue
                }
                set {
                  _$observationRegistrar.mutate(self, keyPath: \\.title, &_title.projectedValue, newValue, _$isIdentityEqual)
                }
              }
            }
            """
        }
    }

    @Test("Forwards typed config argument to factory invocations")
    func observedWrapperForwardsExtras() {
        assertMacro {
            #"""
            struct FeatureState {
              @ObservableStateWrapper(Clamped<Int>.self, config: 0...100)
              @ObservationStateIgnored
              var percent: Int = 150
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              @ObservationStateIgnored
              var percent: Int {
                @storageRestrictions(initializes: _percent)
                init(initialValue) {
                  _percent = Clamped<Int>.makeWrapper(from: initialValue, config: 0 ... 100)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.percent)
                  return _percent.wrappedValue
                }
                set {
                  let newWrapper = type(of: _percent).makeWrapper(from: newValue, config: 0 ... 100)
                  _$observationRegistrar.mutate(self, keyPath: \\.percent, &_percent, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _percent.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.percent, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.percent, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _percent).makeWrapper(from: value, config: 0 ... 100)
                    _percent = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _percent: Clamped<Int> = Clamped<Int>.makeWrapper(from: 150, config: 0 ... 100)
            }
            """
        }
    }

    @Test("Treats implicitly unwrapped optionals as optional values")
    func observedWrapperImplicitlyUnwrappedOptional() {
        assertMacro {
            #"""
            struct FeatureState {
              @ObservableStateWrapper(Box<String>.self)
              @ObservationStateIgnored
              var title: String! = "Hello"
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              @ObservationStateIgnored
              var title: String! {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box<String>.makeWrapper(from: initialValue)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.title)
                  return _title.wrappedValue
                }
                set {
                  let newWrapper = type(of: _title).makeWrapper(from: newValue)
                  _$observationRegistrar.mutate(self, keyPath: \\.title, &_title, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _title.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.title, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.title, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _title).makeWrapper(from: value)
                    _title = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _title: Box<String> = Box<String>.makeWrapper(from: "Hello")
            }
            """
        }
    }

    @Test("Non-optional without inline initializer emits uninitialized storage")
    func nonOptionalNoInlineInitializer() {
        assertMacro {
            #"""
            struct FeatureState {
              @ObservableStateWrapper(Box<String>.self)
              @ObservationStateIgnored
              var title: String
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              @ObservationStateIgnored
              var title: String {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box<String>.makeWrapper(from: initialValue)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.title)
                  return _title.wrappedValue
                }
                set {
                  let newWrapper = type(of: _title).makeWrapper(from: newValue)
                  _$observationRegistrar.mutate(self, keyPath: \\.title, &_title, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _title.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.title, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.title, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _title).makeWrapper(from: value)
                    _title = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _title: Box<String>
            }
            """
        }
    }

    @Test("Optional without initializer defaults storage from nil")
    func optionalNoInitializerUsesNil() {
        assertMacro {
            #"""
            struct FeatureState {
              @ObservableStateWrapper(Box<String?>.self)
              @ObservationStateIgnored
              var title: String?
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              @ObservationStateIgnored
              var title: String? {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box<String?>.makeWrapper(from: initialValue)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.title)
                  return _title.wrappedValue
                }
                set {
                  let newWrapper = type(of: _title).makeWrapper(from: newValue)
                  _$observationRegistrar.mutate(self, keyPath: \\.title, &_title, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _title.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.title, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.title, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _title).makeWrapper(from: value)
                    _title = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _title: Box<String?> = Box<String?>.makeWrapper(from: nil)
            }
            """
        }
    }

    @Test("Explicit projected: false does not emit projected peer")
    func projectedFalse_noPeer() {
        assertMacro {
            #"""
            struct S {
              @ObservableStateWrapper(Box<String>.self, projected: false)
              @ObservationStateIgnored
              var title: String = "Hello"
            }
            """#
        } expansion: {
            """
            struct S {
              @ObservationStateIgnored
              var title: String {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box<String>.makeWrapper(from: initialValue)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.title)
                  return _title.wrappedValue
                }
                set {
                  let newWrapper = type(of: _title).makeWrapper(from: newValue)
                  _$observationRegistrar.mutate(self, keyPath: \\.title, &_title, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _title.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.title, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.title, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _title).makeWrapper(from: value)
                    _title = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _title: Box<String> = Box<String>.makeWrapper(from: "Hello")
            }
            """
        }
    }

    @Test("Non-boolean projected expression defaults to no projected peer")
    func projectedNonBoolean_noPeer() {
        assertMacro {
            #"""
            struct S {
              @ObservableStateWrapper(Box<String>.self, projected: 1 == 2)
              @ObservationStateIgnored
              var title: String = "Hello"
            }
            """#
        } expansion: {
            """
            struct S {
              @ObservationStateIgnored
              var title: String {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box<String>.makeWrapper(from: initialValue)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.title)
                  return _title.wrappedValue
                }
                set {
                  let newWrapper = type(of: _title).makeWrapper(from: newValue)
                  _$observationRegistrar.mutate(self, keyPath: \\.title, &_title, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _title.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.title, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.title, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _title).makeWrapper(from: value)
                    _title = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _title: Box<String> = Box<String>.makeWrapper(from: "Hello")
            }
            """
        }
    }

    @Test("Optional with non-nil initializer seeds storage from that value")
    func optionalWithInitializer_nonNil() {
        assertMacro {
            #"""
            struct S {
              @ObservableStateWrapper(Box<String?>.self)
              @ObservationStateIgnored
              var title: String? = "Hi"
            }
            """#
        } expansion: {
            """
            struct S {
              @ObservationStateIgnored
              var title: String? {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box<String?>.makeWrapper(from: initialValue)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.title)
                  return _title.wrappedValue
                }
                set {
                  let newWrapper = type(of: _title).makeWrapper(from: newValue)
                  _$observationRegistrar.mutate(self, keyPath: \\.title, &_title, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _title.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.title, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.title, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _title).makeWrapper(from: value)
                    _title = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _title: Box<String?> = Box<String?>.makeWrapper(from: "Hi")
            }
            """
        }
    }

    @Test("IUO without inline initializer defaults storage from nil")
    func iuoNoInitializer_usesNil() {
        assertMacro {
            #"""
            struct S {
              @ObservableStateWrapper(Box<String>.self)
              @ObservationStateIgnored
              var title: String!
            }
            """#
        } expansion: {
            """
            struct S {
              @ObservationStateIgnored
              var title: String! {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box<String>.makeWrapper(from: initialValue)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.title)
                  return _title.wrappedValue
                }
                set {
                  let newWrapper = type(of: _title).makeWrapper(from: newValue)
                  _$observationRegistrar.mutate(self, keyPath: \\.title, &_title, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _title.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.title, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.title, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _title).makeWrapper(from: value)
                    _title = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _title: Box<String> = Box<String>.makeWrapper(from: nil)
            }
            """
        }
    }

    @Test("Unknown attribute name is not expanded")
    func unknownAttributeNoExpansion() {
        assertMacro {
            #"""
            struct S {
              @ObservedWrapper(Box<Int>.self)
              var a: Int = 1
            }
            """#
        } expansion: {
            """
            struct S {
              @ObservedWrapper(Box<Int>.self)
              var a: Int = 1
            }
            """
        }
    }

    // MARK: Diagnostics

    @Test("Diagnoses unsupported multi-binding")
    func diagnosticsUnsupportedMultiBinding() {
        assertMacro {
            #"""
            struct S {
              @ObservableStateWrapper(Box<Int>.self) var a: Int, b: Int
            }
            """#
        } diagnostics: {
            """
            struct S {
              @ObservableStateWrapper(Box<Int>.self) var a: Int, b: Int
              ┬────────────────────────────────────────────────────────
              ├─ 🛑 accessor macro can only be applied to a single variable
              ╰─ 🛑 peer macro can only be applied to a single variable
            }
            """
        }
    }

    @Test("Diagnoses existing accessors not supported")
    func diagnosticsExistingAccessors() {
        assertMacro {
            #"""
            struct S {
              @ObservableStateWrapper(Box<Int>.self)
              var a: Int { get { 1 } }
            }
            """#
        } diagnostics: {
            """
            struct S {
              @ObservableStateWrapper(Box<Int>.self)
              var a: Int { get { 1 } }
               ┬         ─────────────
               ╰─ 🛑 @ObservableStateWrapper cannot be applied to properties that already declare accessors
            }
            """
        }
    }

    @Test("Diagnoses missing @ObservationStateIgnored inside @ObservableState")
    func diagnosticsMissingObservationStateIgnored() {
        assertMacro {
            #"""
            @ObservableState
            struct S {
              @ObservableStateWrapper(Box<Int>.self)
              var a: Int = 1
            }
            """#
        } diagnostics: {
            """
            @ObservableState
            struct S {
              @ObservableStateWrapper(Box<Int>.self)
              ┬─────────────────────────────────────
              ╰─ 🛑 Add @ObservationStateIgnored to this property to avoid duplicate accessors from @ObservableState.
              var a: Int = 1
            }
            """
        }
    }

    @Test("Diagnoses incorrect attribute order (@ObservationStateIgnored before macro)")
    func diagnosticsIncorrectAttributeOrder() {
        assertMacro {
            #"""
            struct S {
              @ObservationStateIgnored
              @ObservableStateWrapper(Box<Int>.self)
              var a: Int = 1
            }
            """#
        } diagnostics: {
            """
            struct S {
              @ObservationStateIgnored
              ┬───────────────────────
              ╰─ 🛑 Place @ObservationStateIgnored after this macro. Correct: @ObservableStateWrapper(...) @ObservationStateIgnored var name: Type
              @ObservableStateWrapper(Box<Int>.self)
              var a: Int = 1
            }
            """
        }
    }

    @Test("Diagnoses missing wrapper argument when only labeled config is present")
    func missingWrapperArgument_labeledOnly() {
        assertMacro {
            #"""
            struct S {
              @ObservableStateWrapper(config: 1...10)
              @ObservationStateIgnored
              var a: Int = 0
            }
            """#
        } diagnostics: {
            """
            struct S {
              @ObservableStateWrapper(config: 1...10)
              ┬──────────────────────────────────────
              ╰─ 🛑 @ObservableStateWrapper requires a wrapper type argument (first positional parameter)
              @ObservationStateIgnored
              var a: Int = 0
            }
            """
        }
    }
}
