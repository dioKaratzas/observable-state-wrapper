# ObservableStateWrapper

Observation‑correct, wrapper‑backed state for The Composable Architecture (TCA).

This package provides the `@ObservableStateWrapper` attached Swift macro and a couple of tiny helper
protocols for wrapper authors. You import the library and use the macro in your feature's state; there
is no runtime dependency beyond what your wrapper types provide.

## Why this exists

TCA’s `@ObservableState` synthesizes accessors that record reads and notify writes. Unfortunately, this conflicts with using your own `@propertyWrapper` storage in state:

- You can’t attach a custom wrapper to a stored property and still have reads/writes participate in observation.
- Hand‑written forwarding accessors are boilerplate and easy to get wrong (especially `_modify`).

`@ObservableStateWrapper` is an attached macro that generates observation‑aware accessors for a wrapper‑backed property, so your state stays observable while you keep your storage semantics (clamping, boxing, omit‑coding, presentation, etc.). This macro targets TCA’s registrar (`_$observationRegistrar`) and is specific to `@ObservableState` — it is not a drop‑in for SwiftUI’s `@Observable`.

## What it does

For a declaration like:

```swift
@ObservableStateWrapper(Wrapper<T>.self)
@ObservationStateIgnored
var value: T = initial
```

the macro emits:

- Accessors (`init/get/set/_modify`) that record access and notify mutations via TCA’s registrar
- A private storage peer: `@ObservationStateIgnored private var _value: Wrapper<T> = Wrapper.makeWrapper(from: initial)`
- Optional projected peer when requested: `var $value: Wrapper<T>.ProjectedValue`

Expansion example

```swift
// Input
@ObservableStateWrapper(Wrapper<T>.self)
@ObservationStateIgnored
var value: T = initial

// Expansion
@ObservationStateIgnored
var value: T {
  @storageRestrictions(initializes: _value)
  init(initialValue) {
    _value = Wrapper<T>.makeWrapper(from: initialValue)
  }
  get {
    _$observationRegistrar.access(self, keyPath: \.value)
    return _value.wrappedValue
  }
  set {
    let newWrapper = type(of: _value).makeWrapper(from: newValue)
    _$observationRegistrar.mutate(self, keyPath: \.value, &_value, newWrapper, _$isIdentityEqual)
  }
  _modify {
    var value = _value.wrappedValue
    let oldValue = _$observationRegistrar.willModify(self, keyPath: \.value, &value)
    defer {
      _$observationRegistrar.didModify(self, keyPath: \.value, &value, oldValue, _$isIdentityEqual)
      let newWrapper = type(of: _value).makeWrapper(from: value)
      _value = newWrapper
    }
    yield &value
  }
}

@ObservationStateIgnored
private var _value: Wrapper<T> = Wrapper<T>.makeWrapper(from: initial)

// If projected: true
var $value: Wrapper<T>.ProjectedValue {
  get {
    _$observationRegistrar.access(self, keyPath: \.value)
    return _value.projectedValue
  }
  set {
    _$observationRegistrar.mutate(self, keyPath: \.value, &_value.projectedValue, newValue, _$isIdentityEqual)
  }
}
```

It supports:

- Typed configuration for wrapper construction: `@ObservableStateWrapper(Clamped.self, config: 0 ... 100)`
- Projected access: `projected: true` → `$value` forwards to the wrapper’s `projectedValue`
- IUO treated as optional (`String!` behaves like `String?`)
- Constructor injection: non‑optional without inline `= …` leaves storage uninitialized so you can assign in `init`

## TCA interop (required)

Inside `@ObservableState`, mark the property `@ObservationStateIgnored` so TCA does not also synthesize accessors:

```swift
@ObservableState
struct State {
  @ObservableStateWrapper(OmitCoding<String>.self)
  @ObservationStateIgnored
  var draftNote: String?
}
```

Tip: Place `@ObservationStateIgnored` after `@ObservableStateWrapper`.

## API

```swift
@ObservableStateWrapper(Wrapper.self)
@ObservableStateWrapper(Wrapper.self, config: ConfigValue)
@ObservableStateWrapper(Wrapper.self, projected: true)
@ObservableStateWrapper(Wrapper.self, projected: true, config: ConfigValue)
```

## Wrapper contracts

Base contract (storage only):

```swift
public protocol ObservableWrapper<WrappedValue> {
  associatedtype WrappedValue
  associatedtype Config = Void
  static func makeWrapper(from value: WrappedValue, config: Config) -> Self
}

public extension ObservableWrapper where Config == Void {
  static func makeWrapper(from value: WrappedValue) -> Self { makeWrapper(from: value, config: ()) }
}
```

Projection contract (optional, for `$property`):

```swift
public protocol ObservableWrapperProjected<WrappedValue>: ObservableWrapper {
  associatedtype ProjectedValue
}
```

When you pass `projected: true`, the macro emits `var $value: StorageType.ProjectedValue` that reads/writes `storage.projectedValue` with registrar access/mutate.

## Examples

Skip coding entirely:

```swift
@ObservableStateWrapper(OmitCoding<String>.self)
@ObservationStateIgnored
var draftNote: String?
```

Typed config (clamping):

```swift
@ObservableStateWrapper(Clamped<Int>.self, config: 0 ... 100)
@ObservationStateIgnored
var percent: Int = 150
```

Heap boxing:

```swift
@ObservableStateWrapper(Box<String?>.self)
@ObservationStateIgnored
var scratchNote: String? = nil
```

Presentation with projected peer:

```swift
@ObservableStateWrapper(PresentationState<AlertState<Action.Alert>>.self, projected: true)
@ObservationStateIgnored
var alert: AlertState<Action.Alert>?
// macro emits: var $alert: PresentationState<...>.ProjectedValue
```

Constructor injection (no inline initializer):

```swift
@ObservableStateWrapper(Box<Contacts.State>.self)
@ObservationStateIgnored
var contacts: Contacts.State

init(contacts: Contacts.State) {
  _contacts = Box.makeWrapper(from: contacts)
  // or, if your wrapper exposes an initializer:
  // _contacts = .init(contacts)
}
```

## In‑place edits vs whole‑value replacement

- set runs for whole‑value replacement (`state.percent = 100`).
- _modify yields `inout T` (for mutations like `append`, `sort`) and brackets the change with `willModify`/`didModify` so observers update correctly.

## Writing wrappers

Clamped with typed `Config`:

```swift
@propertyWrapper
public struct Clamped<T: Comparable> {
  public var wrappedValue: T
  public init(wrappedValue: T, range: ClosedRange<T>) {
    wrappedValue = min(max(wrappedValue, range.lowerBound), range.upperBound)
  }
}

extension Clamped: ObservableWrapper {
  public typealias WrappedValue = T
  public typealias Config = ClosedRange<T>
  public static func makeWrapper(from value: T, config: Config) -> Self {
    .init(wrappedValue: min(max(value, config.lowerBound), config.upperBound), range: config)
  }
}
```

Optional‑tolerant Box:

```swift
final class Ref<T> { var val: T; init(_ val: T) { self.val = val } }
@propertyWrapper public struct Box<T> {
  var ref: Ref<T>
  public var wrappedValue: T {
    get { ref.val }
    set { ref.val = newValue }
  }
  public init(wrappedValue: T) { self.ref = Ref(wrappedValue) }
}

extension Box: ObservableWrapper {
  public typealias WrappedValue = T
  public static func makeWrapper(from value: T, config: ()) -> Self { .init(wrappedValue: value) }
}
```

## Diagnostics

- Missing wrapper argument (first positional parameter)
- Wrapper must be `Type.self`
- Property must be `var` and have an explicit type
- Comma‑separated bindings are not supported
- Properties that already declare accessors are not supported
- Missing `@ObservationStateIgnored` when used inside `@ObservableState`
- Incorrect attribute order: place `@ObservationStateIgnored` after `@ObservableStateWrapper`

Note: When `projected: true` but the wrapper does not provide a `projectedValue` and matching `ProjectedValue` type, the projected peer will fail to compile for that property — by design.

## Requirements & installation

- Swift 6.0+
- iOS 13+ / macOS 10.15+ / tvOS 13+ / watchOS 6+

```swift
// Package.swift
dependencies: [
  .package(url: "https://github.com/diokaratzas/observable-state-wrapper", from: "1.0.0")
],
targets: [
  .target(name: "App", dependencies: ["ObservableStateWrapper"]) 
]
```

## Notes

- This package is purpose‑built for TCA’s `@ObservableState`. It is not a drop‑in for SwiftUI’s `@Observable`.
- Inside `@ObservableState`, remember `@ObservationStateIgnored` on properties using this macro.
- Order of emitted members: storage peer first (e.g., `_title`), then `$title` when `projected: true`.

If you run into edge cases or want example wrappers added, please open an issue or PR.

### Creating Wrappers

#### Basic Wrapper (no projection)

Your wrapper must be a **property wrapper** (which provides `wrappedValue`) and conform to `ObservableWrapper`:

```swift
@propertyWrapper  // Property wrappers expose wrappedValue
struct OmitCoding<T> {
  var wrappedValue: T  // Provided by property wrapper - macro reads/writes this
  
  init(wrappedValue: T) {
    self.wrappedValue = wrappedValue
  }
}

extension OmitCoding: ObservableWrapper {
  typealias WrappedValue = T
  typealias Config = Void
  
  static func makeWrapper(from value: T, config: Config) -> Self {
    OmitCoding(wrappedValue: value)
  }
}
```

#### Heap Boxing (Copy-on-Write)

For large values that benefit from copy-on-write semantics:

```swift
@propertyWrapper  // Property wrappers expose wrappedValue
struct Box<T: Equatable>: Equatable {
  private var ref: Ref<T>
  
  init(_ x: T) {
    self.ref = Ref(x)
  }
  
  var wrappedValue: T {
    get { ref.val }
    set {
      if !isKnownUniquelyReferenced(&ref) {
        ref = Ref(newValue)
        return
      }
      ref.val = newValue
    }
  }
  
  var projectedValue: Box<T> { self }
}

extension Box: ObservableWrapper {
  typealias WrappedValue = T
  typealias Config = Void
  
  static func makeWrapper(from value: T, config: Config) -> Self {
    Box(value)
  }
}

// Usage with large data models:
struct LargeDataModel: Equatable {
  let data: [String: Any]
  let metadata: [String]
  // ... lots of data
}
```

#### Wrapper with Configuration

Add a `Config` type for wrappers that need extra parameters:

```swift
@propertyWrapper  // Property wrappers expose wrappedValue
struct Clamped<T: Comparable> {
  var wrappedValue: T  // Provided by property wrapper - macro reads/writes this
  let range: ClosedRange<T>
  
  init(wrappedValue: T, range: ClosedRange<T>) {
    self.wrappedValue = min(max(wrappedValue, range.lowerBound), range.upperBound)
    self.range = range
  }
}

extension Clamped: ObservableWrapper {
  typealias WrappedValue = T
  typealias Config = ClosedRange<T>
  
  static func makeWrapper(from value: T, config: Config) -> Self {
    Clamped(wrappedValue: value, range: config)
  }
}
```

#### Wrapper with Projected Value (for `projected: true`)

To support `projected: true`, your wrapper must:
1. Be a property wrapper with a `projectedValue` property
2. Conform to `ObservableWrapperProjected` 

```swift
@propertyWrapper  // Property wrappers can expose projectedValue
struct CustomPresentationState<State>: ObservableWrapperProjected {
  typealias WrappedValue = State?
  typealias ProjectedValue = Binding<State?>
  typealias Config = Void
  
  var wrappedValue: State?  // Provided by property wrapper
  
  // Property wrapper's projectedValue - the macro will forward to this
  var projectedValue: Binding<State?> {
    Binding(
      get: { self.wrappedValue },
      set: { self.wrappedValue = $0 }
    )
  }
  
  static func makeWrapper(from value: State?, config: Config) -> Self {
    CustomPresentationState(wrappedValue: value)
  }
}
```

**Key differences:**
- **`ObservableWrapper`**: Basic wrapper, no `$property` support
- **`ObservableWrapperProjected`**: Your wrapper must have `projectedValue`, and `projected: true` creates `$property` that forwards to it

## Technical Details: Why Property Wrappers Don't Work with Macros

Here's why you can't mix Swift macros (like `@Observable` or TCA's `@ObservableState`) with property wrappers (`@State`, `@AppStorage`, custom wrappers, etc.):

### 1. Macro rewrite turns stored properties into computed ones
`@Observable` (and TCA's `@ObservableState`) synthesize accessors and observation plumbing by rewriting each stored property into a computed property. Once that happens, the compiler sees your property as computed, not stored. Property wrappers can only attach to stored properties, so you get "Property wrapper cannot be applied to a computed property."

### 2. Wrappers require storage; computed props don't provide it
By design, property wrappers assume there's underlying storage they can manage (`_prop`, `$prop`, `wrappedValue`, `projectedValue`). After the macro expansion, that storage is owned by the macro-generated machinery, not your declaration, so the wrapper has nowhere valid to hook in. Point-Free (TCA) explicitly calls this a Swift limitation: "macros and property wrappers just do not play well together."

### 3. Current compiler doesn't juggle both transformations
Swift's macro system can expand macros, but it can't also "expand" property wrappers or relocate them onto the macro's synthesized backing storage. There's no supported expansion order/interaction to make both work on the same declaration today.

### What this means in practice
- In `@Observable` types, applying wrappers like `@AppStorage`/`@Published` will fail with the computed-property error
- In TCA, the docs and maintainers suggest avoiding property wrappers in state when using `@ObservableState`

### Workarounds
- Put the property wrapper on a separate stored property (or separate object) that isn't transformed by the macro, and bridge it to your observable model
- Replace the wrapper with equivalent code (e.g., manual UserDefaults getter/setter or a small helper type)
- Turn your wrapper into a macro so it participates in codegen rather than runtime wrapping
- **Use `@ObservableStateWrapper`** - which is exactly what this library provides!

## License
MIT. See `LICENSE`.
