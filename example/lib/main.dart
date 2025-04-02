import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluxstate/fluxstate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FluxPersist.initEncryption("my_secure_key_32_bytes_long");
  runApp(const MyApp());
}

/// A simple user model for authentication state.
class User {
  final String name;
  final int age;

  User(this.name, this.age);

  /// Serializes the user to a JSON string.
  String toJson() => jsonEncode({'name': name, 'age': age});

  /// Deserializes a JSON string to a [User] instance.
  static User fromJson(String json) =>
      User(jsonDecode(json)['name'], jsonDecode(json)['age']);
}

/// Manages user authentication state.
class AuthService {
  final user =
      Flux<User>(User("Guest", 0), onInit: () => print("AuthService init")).obs;

  /// Logs in a user with a given [name].
  void login(String name) => user.value = User(name, 25);
}

/// A secondary page demonstrating navigation.
class SecondPage extends StatelessWidget {
  const SecondPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Second Page")),
      body: Center(
        child: ElevatedButton(
          onPressed: () => FluxNavigator.back(context),
          child: const Text("Go Back"),
        ),
      ),
    );
  }
}

/// The main application widget.
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MyHomePage());
  }
}

/// The home page demonstrating FluxState features.
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final counter =
      Flux<int>(0, onDispose: () => print("Counter disposed")).obs;
  late final doubledCounter = counter.computed((val) => val * 2);
  late final authService = FluxState.inject(AuthService());

  @override
  void initState() {
    super.initState();
    FluxPersist.load(counter, "counter", defaultValue: 0, useCache: true);
    FluxPersist.load(authService.user, "user",
        fromJson: User.fromJson,
        defaultValue: User("Guest", 0),
        useCache: true);
    FluxPersist.loadFromFile(counter, "counter_backup", defaultValue: 0);
  }

  @override
  void dispose() {
    counter.dispose();
    doubledCounter.dispose();
    authService.user.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FluxState Demo")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FluxBuilder(
                state: counter,
                builder: (context, value) => Text("Count: $value")),
            FluxBuilder(
                state: doubledCounter,
                builder: (context, value) => Text("Doubled: $value")),
            FluxBuilder(
              state: authService.user,
              builder: (context, User value) =>
                  Text("User: ${value.name}, ${value.age}"),
            ),
            ElevatedButton(
              onPressed: () {
                authService.login("Alice");
                FluxPersist.save(authService.user, "user",
                    toJson: (User u) => u.toJson(), encrypt: true, batch: true);
              },
              child: const Text("Login as Alice (Encrypted, Batched)"),
            ),
            ElevatedButton(
              onPressed: () => FluxNavigator.to(context, const SecondPage()),
              child: const Text("Go to Second Page"),
            ),
            ElevatedButton(
              onPressed: () {
                if (counter.history.length >= 2) {
                  counter.revert(counter.history.length - 2);
                  FluxPersist.save(counter, "counter", cache: true);
                  FluxPersist.saveToFile(counter, "counter_backup");
                }
              },
              child: const Text("Undo Last Change"),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          counter.update((val) => val + 1);
          FluxPersist.save(counter, "counter", batch: true);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
