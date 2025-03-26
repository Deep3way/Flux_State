import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxstate/fluxstate.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class MockSharedPreferences extends Mock implements SharedPreferences {}
class MockDirectory extends Mock implements Directory {}

void main() {
  group('Flux', () {
    test('updates value and notifies stream', () {
      final flux = Flux<int>(0);
      int? lastValue;
      flux.stream.listen((value) => lastValue = value);

      flux.value = 1;
      expect(lastValue, 1);
      expect(flux.value, 1);

      flux.update((val) => val + 1);
      expect(lastValue, 2);
      expect(flux.history, [0, 1, 2]);
    });

    test('computed state updates reactively', () {
      final source = Flux<int>(2);
      final computed = source.computed((val) => val * 3);
      expect(computed.value, 6);

      source.value = 5;
      expect(computed.value, 15);
    });

    test('revert works correctly', () {
      final flux = Flux<int>(0);
      flux.value = 1;
      flux.value = 2;
      flux.revert(1);
      expect(flux.value, 1);
      expect(flux.history, [0, 1, 2, 1]);
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
    late MockSharedPreferences mockPrefs;
    late MockDirectory mockDir;

    setUp(() async {
      mockPrefs = MockSharedPreferences();
      mockDir = MockDirectory();
      SharedPreferences.setMockInitialValues({});
      FluxPersist.initEncryption("test_key_32_bytes_long_here");
      when(getApplicationDocumentsDirectory()).thenAnswer((_) => Future.value(mockDir));
    });

    test('saves and loads int with cache', () async {
      when(mockPrefs.setString(any, any)).thenAnswer((_) => Future.value(true));
      when(mockPrefs.getString("1:counter")).thenReturn("5");

      final flux = Flux<int>(0);
      await FluxPersist.save(flux, "counter", cache: true);
      await FluxPersist.load(flux, "counter", defaultValue: 0, useCache: true);
      expect(flux.value, 5);
      expect(FluxPersist._cache["counter"], "5");
    });

    test('saves and loads custom type with encryption', () async {
      when(mockPrefs.setString(any, any)).thenAnswer((_) => Future.value(true));
      final encryptedData = FluxPersist._encrypt(jsonEncode({"name": "Alice", "age": 25}));
      when(mockPrefs.getString("1:user")).thenReturn(encryptedData);

      final flux = Flux<User>(User("Guest", 0));
      await FluxPersist.save(flux, "user", toJson: (u) => u.toJson(), encrypt: true);
      await FluxPersist.load(flux, "user", fromJson: User.fromJson, defaultValue: User("Guest", 0), decrypt: true);
      expect(flux.value.name, "Alice");
      expect(flux.value.age, 25);
    });

    test('batches writes', () async {
      when(mockPrefs.setString(any, any)).thenAnswer((_) => Future.value(true));
      final flux1 = Flux<int>(1);
      final flux2 = Flux<int>(2);

      await FluxPersist.save(flux1, "key1", batch: true);
      await FluxPersist.save(flux2, "key2", batch: true);
      expect(FluxPersist._writeQueue.length, 2);

      await Future.delayed(Duration(milliseconds: 100));
      verify(mockPrefs.setString("1:key1", "1")).called(1);
      verify(mockPrefs.setString("1:key2", "2")).called(1);
    });

    test('saves and loads from file', () async {
      final tempDir = Directory.systemTemp;
      when(mockDir.path).thenReturn(tempDir.path);

      final flux = Flux<int>(42);
      await FluxPersist.saveToFile(flux, "test_file");
      await FluxPersist.loadFromFile(flux, "test_file", defaultValue: 0);
      expect(flux.value, 42);
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