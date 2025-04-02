
**FluxState by Rudradeep** is a revolutionary, simple, and powerful state management library for Flutter. It combines the best features of existing solutions into a unified package.

## Overview

FluxState provides reactive state management with advanced persistence, dependency injection, navigation, and debugging tools.

### Key Features
- **Reactive State**: `Flux<T>` for reactive state management.
- **Computed States**: Derive values with `computed()`.
- **Dependency Injection**: Global and scoped DI with `FluxState`.
- **Advanced Persistence**: `FluxPersist` with caching, batching, encryption, file storage, and versioning.
- **Navigation**: Simple navigation with `FluxNavigator`.
- **Debugging**: State history and revert functionality.
- **Lifecycle Callbacks**: `onInit` and `onDispose` hooks.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  fluxstate: ^1.3.0
```

Run:

```bash
flutter pub get
```

## Usage

### 1. Basic State Management

```dart
import 'package:fluxstate/fluxstate.dart';
void main() async {
  final counter = Flux<int>(0, onInit: () => print("Counter initialized")).obs;
  counter.value = 1;
}
```

### 2. UI Integration

```dart
import 'package:fluxstate/fluxstate.dart';
void main() async {
FluxBuilder(
  state: counter,
  builder: (context, value) => Text('Count: $value'),
);}
```

### 3. Computed States

```dart
final doubled = counter.computed((val) => val * 2);
```

### 4. Functional Updates

```dart
void main() async {
counter.update((val) => val + 1);}
```

### 5. Dependency Injection

```dart
void main() async {
FluxState.inject(MyService());
final service = FluxState.find<MyService>();
FluxState.injectScoped(MyService(), "feature1");
final scopedService = FluxState.findScoped<MyService>("feature1");}
```

### 6. Advanced Persistence

#### Initialize Encryption

```dart
void main() async {
FluxPersist.initEncryption("my_secure_key_32_bytes_long");}
```

#### Save with Options

```dart
void main() async {
FluxPersist.save(
  counter,
  "counter",
  cache: true,
  encrypt: true,
  batch: true,
);}
```

#### Load with Cache

```dart
void main() async {
FluxPersist.load(
  counter,
  "counter",
  defaultValue: 0,
  useCache: true,
  decrypt: true,
);}
```

#### File Persistence

```dart
void main() async {
FluxPersist.saveToFile(counter, "counter_backup");
FluxPersist.loadFromFile(counter, "counter_backup", defaultValue: 0);}
```

#### Custom Type with Encryption

```dart

class User {
  final String name;
  final int age;
  User(this.name, this.age);
  String toJson() => jsonEncode({'name': name, 'age': age});
  static User fromJson(String json) => User(jsonDecode(json)['name'], jsonDecode(json)['age']);
}
void main() async {
final user = Flux<User>(User("Guest", 0));
FluxPersist.save(user, "user", toJson: (u) => u.toJson(), encrypt: true);
FluxPersist.load(user, "user", fromJson: User.fromJson, defaultValue: User("Guest", 0), decrypt: true);}
```

### 7. Navigation

```dart
void main() async {
FluxNavigator.to(context, SecondPage());
FluxNavigator.back(context);
FluxNavigator.replace(context, SecondPage());}
```

### 8. Debugging

```dart
void main() async {
final flux = Flux<int>(0);
flux.value = 1;
flux.value = 2;
print(flux.history); // [0, 1, 2]
flux.revert(1);
}
```

### 9. Lifecycle Management

```dart
void main() async {
  final flux = Flux<int>(
    0,
    onInit: () => print("Initialized"),
    onDispose: () => print("Disposed"),
  );
  flux.dispose();
}
```

## Example Application

See `example/lib/main.dart`.

## API Reference

### Flux<T>
- **Constructor**: `Flux(T initialValue, {VoidCallback? onInit, VoidCallback? onDispose})`
- **Properties**: `value`, `stream`, `history`
- **Methods**: `update`, `computed`, `revert`, `dispose`

### FluxBuilder<T>
- **Constructor**: `FluxBuilder({required Flux<T> state, required Widget Function(BuildContext, T) builder})`

### FluxState
- **Methods**: `inject`, `injectScoped`, `find`, `findScoped`, `clearScope`

### FluxPersist
- **Methods**: `initEncryption`, `save`, `load`, `saveToFile`, `loadFromFile`

### FluxNavigator
- **Methods**: `to`, `replace`, `back`

## Error Handling
- **Disposed Flux**: Throws `StateError`.
- **Persistence**: Throws `UnsupportedError` for unsupported types without serialization.
- **DI**: Throws `Exception` for missing services.
