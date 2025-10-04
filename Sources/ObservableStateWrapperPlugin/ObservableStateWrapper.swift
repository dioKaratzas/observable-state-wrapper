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

import SwiftSyntax
import SwiftOperators
import SwiftDiagnostics
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

#if !canImport(SwiftSyntax600)
    import SwiftSyntaxMacroExpansion
#endif

public enum ObservableStateWrapper: AccessorMacro, PeerMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let configuration = ObservableStateWrapperConfiguration(
            attribute: attribute,
            declaration: declaration,
            context: context
        ) else {
            return []
        }

        return configuration.makeAccessors()
    }

    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let configuration = ObservableStateWrapperConfiguration(
            attribute: attribute,
            declaration: declaration,
            context: context
        ) else {
            return []
        }

        var peers: [DeclSyntax] = [configuration.makeStorage()]
        if let projected = configuration.makeProjectedPeer() {
            peers.append(projected)
        }
        return peers
    }
}

private struct ObservableStateWrapperConfiguration {
    private struct Strings {
        let wrapperTypeBase: String
        let configArgumentSuffix: String
        let storageType: String
        let storageName: String
        let initialWrapperValue: String
        let keyPath: String
    }

    private let strings: Strings
    private let emitProjected: Bool

    // Tracks declaration shape to decide storage initialization strategy
    private let isOptional: Bool
    private let hasExplicitInitializer: Bool

    init?(
        attribute: AttributeSyntax,
        declaration: some DeclSyntaxProtocol,
        context: some MacroExpansionContext
    ) {
        guard let variable = declaration.as(VariableDeclSyntax.self) else {
            context.diagnose(.init(
                node: attribute,
                message: ObservableStateWrapperDiagnostic.invalidDeclarationPlacement
            ))
            return nil
        }

        guard let binding = variable.bindings.first, variable.bindings.count == 1 else {
            context.diagnose(.init(node: attribute, message: ObservableStateWrapperDiagnostic.unsupportedMultiBinding))
            return nil
        }

        guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
            context.diagnose(.init(
                node: variable.bindingSpecifier,
                message: ObservableStateWrapperDiagnostic.requiresVar
            ))
            return nil
        }

        if let accessorBlock = binding.accessorBlock {
            context.diagnose(.init(
                node: accessorBlock,
                message: ObservableStateWrapperDiagnostic.existingAccessorsNotSupported
            ))
            return nil
        }

        guard let typeAnnotation = binding.typeAnnotation else {
            context.diagnose(.init(node: binding.pattern, message: ObservableStateWrapperDiagnostic.requiresExplicitType))
            return nil
        }

        guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            context.diagnose(.init(node: binding.pattern, message: ObservableStateWrapperDiagnostic.unsupportedPattern))
            return nil
        }

        guard let argumentList = attribute.arguments?.as(LabeledExprListSyntax.self) else {
            context.diagnose(.init(node: attribute, message: ObservableStateWrapperDiagnostic.missingWrapperArgument))
            return nil
        }

        var wrapperArgIndex: LabeledExprListSyntax.Index? = nil
        if wrapperArgIndex == nil, let first = argumentList.first, first.label == nil {
            wrapperArgIndex = argumentList.startIndex
        }
        guard let wrapperArgIndex else {
            context.diagnose(.init(node: attribute, message: ObservableStateWrapperDiagnostic.missingWrapperArgument))
            return nil
        }

        let wrapperArg = argumentList[wrapperArgIndex]

        guard
            let memberAccess = wrapperArg.expression.as(MemberAccessExprSyntax.self),
            memberAccess.declName.baseName.text == "self",
            let wrapperBase = memberAccess.base?.trimmed else {
            // Silent no-op expansion if wrapper is malformed.
            return nil
        }

        // Optional configuration argument: config: <expr>
        let configExpr: ExprSyntax? = {
            if let cfgIndex = argumentList.firstIndex(where: { $0.label?.text == "config" }) {
                return argumentList[cfgIndex].expression.trimmed
            }
            return nil
        }()

        // Optional projected flag: projected: true/false
        let projectedFlag: Bool = {
            if let idx = argumentList.firstIndex(where: { $0.label?.text == "projected" }),
               let bool = argumentList[idx].expression.as(BooleanLiteralExprSyntax.self) {
                return bool.literal.tokenKind == .keyword(.true)
            }
            return false
        }()

        let declaredType = typeAnnotation.type.trimmed
        let normalizedType = ObservableStateWrapperConfiguration.normalizeImplicitlyUnwrappedOptional(type: declaredType)
        // Track optionality and presence of an explicit initializer. When non-optional and
        // lacking an initializer, we defer storage initialization to the user's initializer.
        self.isOptional = normalizedType.is(OptionalTypeSyntax.self)
        self.hasExplicitInitializer = (binding.initializer != nil)
        let storageName = "_" + identifierPattern.identifier.text
        let wrapperTypeBaseDescription = wrapperBase.trimmedDescription
        let storageType = ObservableStateWrapperConfiguration.makeStorageType(
            from: wrapperTypeBaseDescription,
            valueType: normalizedType.trimmedDescription
        )
        let configSuffix = configExpr.map { expr in ", config: \(expr.trimmedDescription)" } ?? ""
        let initialValueDescription = binding.initializer?.value.trimmedDescription ?? "nil"

        self.strings = Strings(
            wrapperTypeBase: wrapperTypeBaseDescription,
            configArgumentSuffix: configSuffix,
            storageType: storageType,
            storageName: storageName,
            initialWrapperValue: initialValueDescription,
            keyPath: identifierPattern.identifier.text
        )
        self.emitProjected = projectedFlag
    }

    func makeAccessors() -> [AccessorDeclSyntax] {
        let keyPathReference = "\\.\(strings.keyPath)"

        let initAccessor: AccessorDeclSyntax =
            """
            @storageRestrictions(initializes: \(raw: strings.storageName))
            init(initialValue) {
            \(raw: strings.storageName) = \(raw: strings.wrapperTypeBase).makeWrapper(from: initialValue\(raw: strings.configArgumentSuffix))
            }
            """

        let getter: AccessorDeclSyntax =
            """
            get {
            _$observationRegistrar.access(self, keyPath: \(raw: keyPathReference))
            return \(raw: strings.storageName).wrappedValue
            }
            """

        let setter: AccessorDeclSyntax =
            """
            set {
            let newWrapper = type(of: \(raw: strings.storageName)).makeWrapper(from: newValue\(raw: strings.configArgumentSuffix))
            _$observationRegistrar.mutate(self, keyPath: \(raw: keyPathReference), &\(raw: strings.storageName), newWrapper, _$isIdentityEqual)
            }
            """
        let modifyAccessor: AccessorDeclSyntax =
            """
            _modify {
            var value = \(raw: strings.storageName).wrappedValue
            let oldValue = _$observationRegistrar.willModify(self, keyPath: \(raw: keyPathReference), &value)
            defer {
            _$observationRegistrar.didModify(self, keyPath: \(raw: keyPathReference), &value, oldValue, _$isIdentityEqual)
            let newWrapper = type(of: \(raw: strings.storageName)).makeWrapper(from: value\(raw: strings.configArgumentSuffix))
            \(raw: strings.storageName) = newWrapper
            }
            yield &value
            }
            """
        return [initAccessor, getter, setter, modifyAccessor]
    }

    func makeStorage() -> DeclSyntax {
        // If the declared property has an explicit initializer or is optional, synthesize a
        // default storage initializer using that expression (or nil). Otherwise, leave the
        // storage uninitialized so it can be set inside a custom initializer.
        if hasExplicitInitializer || isOptional {
            return """
            @ObservationStateIgnored
            private var \(raw: strings.storageName): \(raw: strings.storageType) = \(raw: strings.wrapperTypeBase).makeWrapper(from: \(raw: strings.initialWrapperValue)\(raw: strings.configArgumentSuffix))
            """
        } else {
            return """
            @ObservationStateIgnored
            private var \(raw: strings.storageName): \(raw: strings.storageType)
            """
        }
    }

    func makeProjectedPeer() -> DeclSyntax? {
        guard emitProjected else {
            return nil
        }
        let keyPathReference = "\\.\(strings.keyPath)"
        let projectedName = "$" + strings.keyPath
        return """
        var \(raw: projectedName): \(raw: strings.storageType).ProjectedValue {
        get {
        _$observationRegistrar.access(self, keyPath: \(raw: keyPathReference))
        return \(raw: strings.storageName).projectedValue
        }
        set {
        _$observationRegistrar.mutate(self, keyPath: \(raw: keyPathReference), &\(raw: strings.storageName).projectedValue, newValue, _$isIdentityEqual)
        }
        }
        """
    }

    private static func normalizeImplicitlyUnwrappedOptional(type: TypeSyntax) -> TypeSyntax {
        if let implicitlyUnwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            let optional = OptionalTypeSyntax(
                wrappedType: implicitlyUnwrapped.wrappedType.trimmed,
                questionMark: .postfixQuestionMarkToken()
            )
            return TypeSyntax(optional)
        }
        return type
    }

    private static func makeStorageType(from wrapper: String, valueType: String) -> String {
        if wrapper.contains("<") {
            return wrapper
        }

        return "\(wrapper)<\(valueType)>"
    }
}

private enum ObservableStateWrapperDiagnostic: DiagnosticMessage {
    case invalidDeclarationPlacement
    case unsupportedMultiBinding
    case requiresVar
    case existingAccessorsNotSupported
    case requiresExplicitType
    case unsupportedPattern
    case missingWrapperArgument
    case invalidWrapperExpression

    var severity: DiagnosticSeverity { .error }

    var message: String {
        switch self {
        case .invalidDeclarationPlacement:
            return "@ObservableStateWrapper can only be attached to stored properties"
        case .unsupportedMultiBinding:
            return "@ObservableStateWrapper does not support comma-separated property bindings"
        case .requiresVar:
            return "@ObservableStateWrapper requires a 'var' declaration"
        case .existingAccessorsNotSupported:
            return "@ObservableStateWrapper cannot be applied to properties that already declare accessors"
        case .requiresExplicitType:
            return "@ObservableStateWrapper requires an explicit type annotation"
        case .unsupportedPattern:
            return "@ObservableStateWrapper only supports simple identifier bindings"
        case .missingWrapperArgument:
            return "@ObservableStateWrapper requires a wrapper type argument (first positional parameter)"
        case .invalidWrapperExpression:
            return "The wrapper type argument must be a type reference followed by '.self'"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "ObservableStateWrapper", id: String(describing: self))
    }
}
