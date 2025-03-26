import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:fluxstate/fluxstate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence utilities for saving and loading [Flux] state.
class FluxPersist {
  static final Map<String, dynamic> _cache = {};
  static const int _currentVersion = 1;
  static final List<_PendingWrite> _writeQueue = [];
  static bool _isProcessingQueue = false;
  static Uint8List? _encryptionKey;

  /// Initializes encryption with a [key] hashed to a 32-byte key.
  static void initEncryption(String key) {
    _encryptionKey = Uint8List.fromList(sha256.convert(utf8.encode(key)).bytes);
  }

  /// Saves a [state]’s value to persistent storage.
  static Future<void> save<T>(
      Flux<T> state,
      String key, {
        String Function(T)? toJson,
        bool cache = true,
        bool encrypt = false,
        bool batch = false,
      }) async {
    final value = state.value;
    String? serialized;

    if (T == int) {
      serialized = value.toString();
    } else if (T == String) {
      serialized = value as String;
    } else if (T == bool) {
      serialized = (value as bool).toString();
    } else if (toJson != null) {
      serialized = toJson(value);
    } else {
      throw UnsupportedError(
          "Type $T is not supported without a toJson function");
    }

    if (encrypt && _encryptionKey != null) {
      serialized = _encrypt(serialized);
    }

    if (cache) {
      _cache[key] = serialized;
    }

    if (batch) {
      _writeQueue.add(_PendingWrite(key, serialized));
      _processQueue();
    } else {
      await _writeToStorage(key, serialized);
    }
  }

  /// Loads a value into a [state] from persistent storage.
  static Future<void> load<T>(
      Flux<T> state,
      String key, {
        T? defaultValue,
        T Function(String)? fromJson,
        bool useCache = true,
        bool decrypt = false,
      }) async {
    String? serialized;

    if (useCache && _cache.containsKey(key)) {
      serialized = _cache[key] as String;
    } else {
      final prefs = await SharedPreferences.getInstance();
      serialized = prefs.getString(_versionedKey(key));
      if (serialized != null && useCache) {
        _cache[key] = serialized;
      }
    }

    if (serialized == null) {
      if (defaultValue != null) state.value = defaultValue;
      return;
    }

    if (decrypt && _encryptionKey != null) {
      serialized = _decrypt(serialized);
    }

    if (T == int) {
      state.value = int.parse(serialized) as T;
    } else if (T == String) {
      state.value = serialized as T;
    } else if (T == bool) {
      state.value = (serialized == "true") as T;
    } else if (fromJson != null) {
      state.value = fromJson(serialized);
    } else {
      throw UnsupportedError("Type $T is not supported without a fromJson function");
    }
  }



  /// Saves a [state]’s value to a file.
  static Future<void> saveToFile<T>(
      Flux<T> state,
      String fileName, {
        String Function(T)? toJson,
        bool encrypt = false,
      }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    String serialized =
    toJson != null ? toJson(state.value) : state.value.toString();

    if (encrypt && _encryptionKey != null) {
      serialized = _encrypt(serialized);
    }

    await file.writeAsString(serialized);
  }

  /// Loads a value from a file into a [state].
  static Future<void> loadFromFile<T>(
      Flux<T> state,
      String fileName, {
        T Function(String)? fromJson,
        T? defaultValue,
        bool decrypt = false,
      }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    if (!await file.exists()) {
      if (defaultValue != null) state.value = defaultValue;
      return;
    }

    String serialized = await file.readAsString();
    if (decrypt && _encryptionKey != null) {
      serialized = _decrypt(serialized);
    }

    state.value = fromJson != null ? fromJson(serialized) : serialized as T;
  }

  /// Processes the batch write queue asynchronously.
  static Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    final prefs = await SharedPreferences.getInstance();
    while (_writeQueue.isNotEmpty) {
      final write = _writeQueue.removeAt(0);
      await prefs.setString(_versionedKey(write.key), write.value);
    }

    _isProcessingQueue = false;
  }

  /// Writes a [value] to storage under a [key].
  static Future<void> _writeToStorage(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionedKey(key), value);
  }

  /// Prepends the version to a [key] for versioning support.
  static String _versionedKey(String key) => "$_currentVersion:$key";

  /// Encrypts [data] using a simple XOR with the encryption key.
  static String _encrypt(String data) {
    if (_encryptionKey == null) return data;
    final bytes = utf8.encode(data);
    final encrypted = bytes
        .map((b) => b ^ _encryptionKey![b % _encryptionKey!.length])
        .toList();
    return base64Encode(encrypted);
  }

  /// Decrypts [data] using the same XOR method.
  static String _decrypt(String data) {
    if (_encryptionKey == null) return data;
    final bytes = base64Decode(data);
    final decrypted = bytes
        .map((b) => b ^ _encryptionKey![b % _encryptionKey!.length])
        .toList();
    return utf8.decode(decrypted);
  }
}

/// Represents a pending write operation for batch processing.
class _PendingWrite {
  final String key;
  final String value;

  _PendingWrite(this.key, this.value);
}