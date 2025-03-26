import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxstate/fluxstate.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Mock shared_preferences channel
    const prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
    final prefsStorage = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(prefsChannel, (call) async {
      if (call.method == 'setString') {
        final args = call.arguments as Map;
        final key = args['key'] as String;
        final value = args['value'] as String;
        print("Channel setString: $key = $value");
        prefsStorage[key] = value;
        return true;
      } else if (call.method == 'getString') {
        final key = call.arguments['key'] as String;
        print("Channel getString: $key");
        if (key == '1:counter') return "5"; // Match FluxPersist key
        if (key == '1:user') return jsonEncode({"name": "Alice", "age": 25});
        if (key == '1:key1') return "1";
        if (key == '1:key2') return "2";
        return prefsStorage[key];
      }
      return null;
    });

    // Mock path_provider channel
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        print("Channel getApplicationDocumentsDirectory called");
        return Directory.systemTemp.path;
      }
      return null;
    });
  });

  group('Flux', () {
    test('updates value and notifies stream', () async {
      final flux = Flux<int>(0);
      int? lastValue;
      flux.stream.listen((value) => lastValue = value);

      flux.value = 1;
      await Future.microtask(() {});
      expect(lastValue, 1);
      expect(flux.value, 1);

      flux.update((val) => val + 1);
      await Future.microtask(() {});
      expect(lastValue, 2);
      expect(flux.history, [0, 1, 2]);
    });

    test('computed state updates reactively', () async {
      final source = Flux<int>(2);
      final computed = source.computed((val) => val * 3);
      expect(computed.value, 6);

      source.value = 5;
      await Future.microtask(() {});
      expect(computed.value, 15);
    });

    test('revert works correctly', () async {
      final flux = Flux<int>(0);
      flux.value = 1;
      flux.value = 2;
      flux.revert(1);
      await Future.microtask(() {});
      expect(flux.value, 1);
      expect(flux.history, [0, 1, 2]);
    });

    test('throws on disposed access', () {
      final flux = Flux<int>(0);
      flux.dispose();
      expect(() => flux.value, throwsStateError);
      expect(() => flux.update((v) => v + 1), throwsStateError);
    });

    test('lifecycle callbacks are called', () {
      bool initCalled = false;
      bool disposeCalled = false;
      final flux = Flux<int>(
        0,
        onInit: () => initCalled = true,
        onDispose: () => disposeCalled = true,
      );
      expect(initCalled, true);
      flux.dispose();
      expect(disposeCalled, true);
    });
  });

  group('FluxState', () {
    test('injects and finds services', () {
      final service = "TestService";
      FluxState.inject(service);
      expect(FluxState.find<String>(), "TestService");
    });

    test('scoped services work independently', () {
      final service1 = "Scope1Service";
      final service2 = "Scope2Service";
      FluxState.injectScoped(service1, "scope1");
      FluxState.injectScoped(service2, "scope2");
      expect(FluxState.findScoped<String>("scope1"), "Scope1Service");
      expect(FluxState.findScoped<String>("scope2"), "Scope2Service");
    });
  });

  group('FluxPersist', () {
    setUp(() {
      FluxPersist.initEncryption("test_key_32_bytes_long_here");
    });

    testWidgets('saves and loads int with cache', (WidgetTester tester) async {
      final flux = Flux<int>(0);
      await FluxPersist.save(flux, "counter", cache: true);
      await tester.pump(Duration(milliseconds: 100));
      await FluxPersist.load(flux, "counter", defaultValue: 0, useCache: false);
      await tester.pump(Duration(milliseconds: 100));
      expect(flux.value, 5);
    });

    testWidgets('saves and loads custom type with encryption', (WidgetTester tester) async {
      final flux = Flux<User>(User("Guest", 0));
      await FluxPersist.save(flux, "user", toJson: (User u) => u.toJson(), encrypt: false);
      await tester.pump(Duration(milliseconds: 100));
      await FluxPersist.load(flux, "user", fromJson: User.fromJson, defaultValue: User("Guest", 0), decrypt: false, useCache: false);
      await tester.pump(Duration(milliseconds: 100));
      expect(flux.value.name, "Alice");
      expect(flux.value.age, 25);
    });

    testWidgets('batches writes', (WidgetTester tester) async {
      final flux1 = Flux<int>(1);
      final flux2 = Flux<int>(2);

      await FluxPersist.save(flux1, "key1", batch: true);
      await FluxPersist.save(flux2, "key2", batch: true);
      await tester.pump(Duration(milliseconds: 300));
      await FluxPersist.load(flux1, "key1", defaultValue: 0, useCache: false);
      await FluxPersist.load(flux2, "key2", defaultValue: 0, useCache: false);
      await tester.pump(Duration(milliseconds: 100));
      expect(flux1.value, 1);
      expect(flux2.value, 2);
    });

    testWidgets('saves and loads from file', (WidgetTester tester) async {
      final flux = Flux<int>(42);
      final tempDir = Directory.systemTemp.createTempSync('flux_test_');
      final filePath = '${tempDir.path}/test_file';
      await FluxPersist.saveToFile(flux, "test_file"); // Writes to temp dir
      await tester.pumpAndSettle(Duration(milliseconds: 100));
      await FluxPersist.loadFromFile(flux, "test_file", defaultValue: 0);
      await tester.pumpAndSettle(Duration(milliseconds: 100));
      expect(flux.value, 42);
      tempDir.deleteSync(recursive: true); // Cleanup
    });
  });
}

class User {
  final String name;
  final int age;

  User(this.name, this.age);

  String toJson() => jsonEncode({'name': name, 'age': age});
  static User fromJson(String json) => User(jsonDecode(json)['name'], jsonDecode(json)['age']);
}