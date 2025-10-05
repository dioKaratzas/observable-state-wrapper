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
import SwiftSyntaxMacroExpansion

/// # ObservableStateWrapper
/// Macro that wires a stored property to a wrapper type providing
/// `wrappedValue` access, projected access (optional), and hooks for
/// observation/registration.
///
/// ## Requirements for annotated property
/// - Must be a **stored** `var` (no explicit accessors)
/// - Must have an **explicit** type annotation
/// - Only **simple identifier** bindings are supported
/// - First unlabeled attribute argument must be a **Type.self** expression
/// - `@ObservationStateIgnored` **must** also decorate the property and
///   **must** appear **after** this macro attribute
public enum ObservableStateWrapper: AccessorMacro, PeerMacro {
    // MARK: - AccessorMacro
    public static func expansion(
        of attribute: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let configuration = ObservableStateWrapperConfiguration.make(
            attribute: attribute,
            declaration: declaration,
            context: context,
            emitDiagnostics: true
        ) else {
            return []
        }
        return configuration.makeAccessors()
    }

    // MARK: - PeerMacro
    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let configuration = ObservableStateWrapperConfiguration.make(
            attribute: attribute,
            declaration: declaration,
            context: context,
            emitDiagnostics: false
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

// MARK: - Configuration
private struct ObservableStateWrapperConfiguration {
    // MARK: Constants
    private static let wrapperAttrName = "ObservableStateWrapper"
    private static let ignoredAttrName = "ObservationStateIgnored"

    /// Small bag of strings used to render code with `SwiftSyntaxBuilder`.
    private struct Strings {
        let wrapperTypeBase: String // e.g., `Wrapper<Foo>`
        let configArgumentSuffix: String // e.g., `, config: someExpr`
        let storageType: String // same as `wrapperTypeBase` (aliased for clarity)
        let storageName: String // e.g., `_<property>`
        let initialWrapperValue: String // inline initializer or `nil`
        let keyPath: String // property name as key path tail
    }

    private let strings: Strings
    private let emitProjected: Bool

    // Tracks declaration shape to decide storage initialization strategy
    private let isOptional: Bool
    private let hasExplicitInitializer: Bool

    // MARK: Factory
    /// Factory wrapper to keep the initializer lean and readable.
    static func make(
        attribute: AttributeSyntax,
        declaration: some DeclSyntaxProtocol,
        context: some MacroExpansionContext,
        emitDiagnostics: Bool
    ) -> ObservableStateWrapperConfiguration? {
        Self(attribute: attribute, declaration: declaration, context: context, emitDiagnostics: emitDiagnostics)
    }

    // MARK: Init
    init?(
        attribute: AttributeSyntax,
        declaration: some DeclSyntaxProtocol,
        context: some MacroExpansionContext,
        emitDiagnostics: Bool = true
    ) {
        // Local diagnose helper that can be silenced per call site.
        let diagnose: (Syntax, ObservableStateWrapperDiagnostic) -> Void = { node, message in
            if emitDiagnostics {
                context.diagnose(.init(node: node, message: message))
            }
        }

        // Validate declaration kind & shape
        guard let variable = declaration.as(VariableDeclSyntax.self) else {
            diagnose(Syntax(attribute), .invalidDeclarationPlacement)
            return nil
        }

        guard let binding = variable.bindings.first, variable.bindings.count == 1 else {
            diagnose(Syntax(attribute), .unsupportedMultiBinding)
            return nil
        }

        // Must be a `var` so we can synthesize accessors
        guard variable.bindingSpecifier.tokenKind == .keyword(.var) else {
            diagnose(Syntax(variable.bindingSpecifier), .requiresVar)
            return nil
        }

        // Stored property only — no pre-existing accessor block
        if let accessorBlock = binding.accessorBlock {
            diagnose(Syntax(accessorBlock), .existingAccessorsNotSupported)
            return nil
        }

        // Explicit type required
        guard let typeAnnotation = binding.typeAnnotation else {
            diagnose(Syntax(binding.pattern), .requiresExplicitType)
            return nil
        }

        // Only simple identifier bindings (no tuples/patterns)
        guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            diagnose(Syntax(binding.pattern), .unsupportedPattern)
            return nil
        }

        // Parse attribute arguments
        guard let argumentList = attribute.arguments?.as(LabeledExprListSyntax.self) else {
            diagnose(Syntax(attribute), .missingWrapperArgument)
            return nil
        }

        // First **unlabeled** argument must be `Type.self`
        guard let wrapperArgIndex = argumentList.firstIndex(where: { $0.label == nil }) else {
            diagnose(Syntax(attribute), .missingWrapperArgument)
            return nil
        }
        let wrapperArg = argumentList[wrapperArgIndex]

        // Expect a well-formed `Type.self`
        guard
            let memberAccess = wrapperArg.expression.as(MemberAccessExprSyntax.self),
            memberAccess.declName.baseName.text == "self",
            let wrapperBase = memberAccess.base?.trimmed else {
            diagnose(Syntax(wrapperArg.expression), .invalidWrapperExpression)
            return nil
        }

        // Enforce TCA interop: ensure `@ObservationStateIgnored` exists and is ordered **after** this macro
        let order = Self.findAttributeOrder(in: variable)
        guard order.hasObservationStateIgnored else {
            diagnose(Syntax(attribute), .missingObservationStateIgnored)
            return nil
        }
        if let wrapperIdx = order.wrapperIndex, let ignoredIdx = order.ignoredIndex, wrapperIdx > ignoredIdx {
            diagnose(order.ignoredAttrNode ?? Syntax(variable), .incorrectAttributeOrder)
            return nil
        }

        let configExpr = Self.readConfigExpr(from: argumentList)
        let projectedFlag = Self.readProjectedFlag(from: argumentList)

        // Infer declaration traits used later to decide storage init strategy
        let declaredType = typeAnnotation.type.trimmed
        // Normalize IUO (e.g., `T!`) to `T?` so we treat it uniformly as optional
        let normalizedType = Self.normalizeImplicitlyUnwrappedOptional(type: declaredType)
        self.isOptional = normalizedType.is(OptionalTypeSyntax.self)
        self.hasExplicitInitializer = (binding.initializer != nil)

        // Pre-compute strings that feed the builders
        let propertyName = identifierPattern.identifier.text
        let storageName = "_" + propertyName
        let wrapperTypeBaseDescription = wrapperBase.trimmedDescription
        let configSuffix = configExpr.map { ", config: \($0.trimmedDescription)" } ?? ""
        let initialValueDescription = binding.initializer?.value.trimmedDescription ?? "nil"

        self.strings = Strings(
            wrapperTypeBase: wrapperTypeBaseDescription,
            configArgumentSuffix: configSuffix,
            storageType: wrapperTypeBaseDescription,
            storageName: storageName,
            initialWrapperValue: initialValueDescription,
            keyPath: propertyName
        )
        self.emitProjected = projectedFlag
    }

    // MARK: Synonyms & Small Helpers
    private var keyPathReference: String { "\\.\(strings.keyPath)" }

    // MARK: Builders
    func makeAccessors() -> [AccessorDeclSyntax] {
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

    /// Creates the private storage. If the declared property is optional or has
    /// an explicit initializer, we synthesize a default storage initializer
    /// using that expression (or `nil`). Otherwise, we leave it uninitialized so
    /// users can wire it up inside custom `init`s.
    func makeStorage() -> DeclSyntax {
        if hasExplicitInitializer || isOptional {
            return
                """
                @ObservationStateIgnored
                private var \(raw: strings.storageName): \(raw: strings.storageType) = \(raw: strings.wrapperTypeBase).makeWrapper(from: \(raw: strings.initialWrapperValue)\(raw: strings.configArgumentSuffix))
                """
        } else {
            return
                """
                @ObservationStateIgnored
                private var \(raw: strings.storageName): \(raw: strings.storageType)
                """
        }
    }

    /// Creates the projected `$property` peer, when requested via
    /// `projected: true`.
    func makeProjectedPeer() -> DeclSyntax? {
        guard emitProjected else {
            return nil
        }
        let projectedName = "$" + strings.keyPath
        return
            """
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

    // MARK: - Static helpers
    /// Normalize IUO (`T!`) into optional (`T?`) so optionality logic is consistent.
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

    /// Returns the `config:` expression when present.
    private static func readConfigExpr(from arguments: LabeledExprListSyntax) -> ExprSyntax? {
        guard let cfgIndex = arguments.firstIndex(where: { $0.label?.text == "config" }) else {
            return nil
        }
        return arguments[cfgIndex].expression.trimmed
    }

    /// Returns the `projected:` boolean flag, defaulting to `false`.
    private static func readProjectedFlag(from arguments: LabeledExprListSyntax) -> Bool {
        guard
            let idx = arguments.firstIndex(where: { $0.label?.text == "projected" }),
            let bool = arguments[idx].expression.as(BooleanLiteralExprSyntax.self) else {
            return false
        }
        return bool.literal.tokenKind == .keyword(.true)
    }

    /// Finds indices of the relevant attributes to enforce ordering rules.
    private static func findAttributeOrder(in variable: VariableDeclSyntax) -> (
        hasObservationStateIgnored: Bool,
        wrapperIndex: Int?,
        ignoredIndex: Int?,
        ignoredAttrNode: Syntax?
    ) {
        var hasObservationStateIgnored = false
        var wrapperIndex: Int? = nil
        var ignoredIndex: Int? = nil
        var ignoredAttrNode: Syntax? = nil

        for (attributeIndex, element) in variable.attributes.enumerated() {
            guard let attr = element.as(AttributeSyntax.self) else {
                continue
            }
            let simpleName = lastPathComponent(of: attr.attributeName.trimmedDescription)
            if simpleName == wrapperAttrName {
                wrapperIndex = attributeIndex
            } else if simpleName == ignoredAttrName {
                ignoredIndex = attributeIndex
                ignoredAttrNode = Syntax(attr)
                hasObservationStateIgnored = true
            }
        }
        return (hasObservationStateIgnored, wrapperIndex, ignoredIndex, ignoredAttrNode)
    }

    /// Returns the last path component of a possibly module-qualified attribute name.
    private static func lastPathComponent(of name: String) -> String {
        name.split(separator: ".").last.map(String.init) ?? name
    }
}

// MARK: - Diagnostics
private enum ObservableStateWrapperDiagnostic: DiagnosticMessage {
    case invalidDeclarationPlacement
    case unsupportedMultiBinding
    case requiresVar
    case existingAccessorsNotSupported
    case requiresExplicitType
    case unsupportedPattern
    case missingWrapperArgument
    case invalidWrapperExpression
    case missingObservationStateIgnored
    case incorrectAttributeOrder

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
        case .missingObservationStateIgnored:
            return "Add @ObservationStateIgnored to this property to avoid duplicate accessors from @ObservableState."
        case .incorrectAttributeOrder:
            return "Place @ObservationStateIgnored after this macro. Correct: @ObservableStateWrapper(...) @ObservationStateIgnored var name: Type"
        }
    }

    var diagnosticID: MessageID { MessageID(domain: "ObservableStateWrapper", id: String(describing: self)) }
}
