// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "observable-state-wrapper",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ObservableStateWrapper",
            targets: ["ObservableStateWrapper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"603.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.6.4"),
    ],
    targets: [
        .macro(
            name: "ObservableStateWrapperPlugin",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        // Macro declarations (what users import)
        .target(
            name: "ObservableStateWrapper",
            dependencies: ["ObservableStateWrapperPlugin"]
        ),

        // Tests
        .testTarget(
            name: "ObservableStateWrapperTests",
            dependencies: [
                "ObservableStateWrapper",
                "ObservableStateWrapperPlugin",
                .product(name: "MacroTesting", package: "swift-macro-testing")
            ]
        ),
    ]
)
