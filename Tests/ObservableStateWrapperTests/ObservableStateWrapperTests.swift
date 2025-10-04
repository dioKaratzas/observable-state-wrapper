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
              @ObservableStateWrapper(OmitCoding.self)
              var unresolvedAddresses: Set<EthereumAddress>? = nil
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              var unresolvedAddresses: Set<EthereumAddress>? {
                @storageRestrictions(initializes: _unresolvedAddresses)
                init(initialValue) {
                  _unresolvedAddresses = OmitCoding.makeWrapper(from: initialValue)
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
              private var _unresolvedAddresses: OmitCoding<Set<EthereumAddress>?> = OmitCoding.makeWrapper(from: nil)
            }
            """
        }
    }

    @Test("Generates projected peer when requested")
    func observedWrapperProjectedPeer() {
        assertMacro {
            #"""
            struct FeatureState {
              @ObservableStateWrapper(Box.self, projected: true)
              var title: String! = "Hello"
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              var title: String! {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box.makeWrapper(from: initialValue)
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
              private var _title: Box<String?> = Box.makeWrapper(from: "Hello")

              var $title: Box<String?>.ProjectedValue {
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

    @Test("Generates projected peer for presentation-style wrapper")
    func observedWrapperProjectedPeerPresentation() {
        assertMacro {
            #"""
            struct FeatureState {
              @ObservableStateWrapper(OmitCodingPresentationState<AlertState<Action.Alert>>.self, projected: true)
              var alert: AlertState<Action.Alert>? = nil
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              var alert: AlertState<Action.Alert>? {
                @storageRestrictions(initializes: _alert)
                init(initialValue) {
                  _alert = OmitCodingPresentationState<AlertState<Action.Alert>>.makeWrapper(from: initialValue)
                }
                get {
                  _$observationRegistrar.access(self, keyPath: \\.alert)
                  return _alert.wrappedValue
                }
                set {
                  let newWrapper = type(of: _alert).makeWrapper(from: newValue)
                  _$observationRegistrar.mutate(self, keyPath: \\.alert, &_alert, newWrapper, _$isIdentityEqual)
                }
                _modify {
                  var value = _alert.wrappedValue
                  let oldValue = _$observationRegistrar.willModify(self, keyPath: \\.alert, &value)
                  defer {
                    _$observationRegistrar.didModify(self, keyPath: \\.alert, &value, oldValue, _$isIdentityEqual)
                    let newWrapper = type(of: _alert).makeWrapper(from: value)
                    _alert = newWrapper
                  }
                  yield &value
                }
              }

              @ObservationStateIgnored
              private var _alert: OmitCodingPresentationState<AlertState<Action.Alert>> = OmitCodingPresentationState<AlertState<Action.Alert>>.makeWrapper(from: nil)

              var $alert: OmitCodingPresentationState<AlertState<Action.Alert>>.ProjectedValue {
                get {
                  _$observationRegistrar.access(self, keyPath: \\.alert)
                  return _alert.projectedValue
                }
                set {
                  _$observationRegistrar.mutate(self, keyPath: \\.alert, &_alert.projectedValue, newValue, _$isIdentityEqual)
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
              @ObservableStateWrapper(Clamped.self, config: 0...100)
              var percent: Int = 150
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              var percent: Int {
                @storageRestrictions(initializes: _percent)
                init(initialValue) {
                  _percent = Clamped.makeWrapper(from: initialValue, config: 0 ... 100)
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
              private var _percent: Clamped<Int> = Clamped.makeWrapper(from: 150, config: 0 ... 100)
            }
            """
        }
    }

    @Test("Treats implicitly unwrapped optionals as optional values")
    func observedWrapperImplicitlyUnwrappedOptional() {
        assertMacro {
            #"""
            struct FeatureState {
              @ObservableStateWrapper(Box.self)
              var title: String! = "Hello"
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              var title: String! {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box.makeWrapper(from: initialValue)
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
              private var _title: Box<String?> = Box.makeWrapper(from: "Hello")
            }
            """
        }
    }

    @Test("Non-optional without inline initializer emits uninitialized storage")
    func nonOptionalNoInlineInitializer() {
        assertMacro {
            #"""
            struct FeatureState {
              @ObservableStateWrapper(Box.self)
              var title: String
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              var title: String {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box.makeWrapper(from: initialValue)
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
              @ObservableStateWrapper(Box.self)
              var title: String?
            }
            """#
        } expansion: {
            """
            struct FeatureState {
              var title: String? {
                @storageRestrictions(initializes: _title)
                init(initialValue) {
                  _title = Box.makeWrapper(from: initialValue)
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
              private var _title: Box<String?> = Box.makeWrapper(from: nil)
            }
            """
        }
    }

    @Test("Diagnoses unsupported multi-binding")
    func diagnosticsUnsupportedMultiBinding() {
        assertMacro {
            #"""
            struct S {
              @ObservableStateWrapper(Box.self) var a: Int, b: Int
            }
            """#
        } diagnostics: {
            """
            struct S {
              @ObservableStateWrapper(Box.self) var a: Int, b: Int
              ┬───────────────────────────────────────────────────
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
              @ObservableStateWrapper(Box.self)
              var a: Int { get { 1 } }
            }
            """#
        } diagnostics: {
            """
            struct S {
              @ObservableStateWrapper(Box.self)
              var a: Int { get { 1 } }
                         ┬────────────
               │         ╰─ 🛑 @ObservableStateWrapper cannot be applied to properties that already declare accessors
               ┬         ─────────────
               ╰─ 🛑 @ObservableStateWrapper cannot be applied to properties that already declare accessors
            }
            """
        }
    }

    @Test("Unknown attribute name is not expanded")
    func unknownAttributeNoExpansion() {
        assertMacro {
            #"""
            struct S {
              @ObservedWrapper(Box.self)
              var a: Int = 1
            }
            """#
        } expansion: {
            """
            struct S {
              @ObservedWrapper(Box.self)
              var a: Int = 1
            }
            """
        }
    }
}
