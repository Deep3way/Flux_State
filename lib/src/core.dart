import 'dart:async';
import 'package:flutter/material.dart';

/// A reactive state container that manages a value of type [T],
/// provides a stream of updates, and supports history tracking.
class Flux<T> {
  T _value;
  final StreamController<T> _controller = StreamController.broadcast();
  final List<T> _history = [];
  bool _disposed = false;
  final VoidCallback? onInit;
  final VoidCallback? onDispose;

  /// Creates a [Flux] instance with an initial [value].
  /// [onInit] is called upon creation, [onDispose] when disposed.
  Flux(this._value, {this.onInit, this.onDispose}) {
    _history.add(_value);
    onInit?.call();
  }

  /// Gets the current value. Throws [StateError] if disposed.
  T get value => _disposed ? throw StateError("Flux is disposed") : _value;

  /// Sets a new [newValue], updates history, and notifies listeners.
  set value(T newValue) {
    if (_disposed) throw StateError("Cannot set value on disposed Flux");
    _value = newValue;
    _history.add(_value);
    _controller.add(_value);
  }

  /// Updates the value using an [updater] function, then notifies listeners.
  void update(T Function(T) updater) {
    if (_disposed) throw StateError("Cannot update disposed Flux");
    _value = updater(_value);
    _history.add(_value);
    _controller.add(_value);
  }

  /// Stream of value changes for reactive updates.
  Stream<T> get stream => _controller.stream;

  /// Returns this [Flux] instance (useful for method chaining).
  Flux<T> get obs => this;

  /// Creates a computed [Flux] based on a [computeFn] applied to this value.
  Flux<R> computed<R>(R Function(T) computeFn) {
    final computedFlux = Flux<R>(computeFn(_value));
    stream.listen((value) {
      if (!_disposed) computedFlux.value = computeFn(value);
    });
    return computedFlux;
  }

  /// Returns an unmodifiable list of historical values.
  List<T> get history => List.unmodifiable(_history);

  /// Reverts to a value at [historyIndex]. Does not append to history.
  void revert(int historyIndex) {
    if (_disposed) throw StateError("Cannot revert disposed Flux");
    if (historyIndex < 0 || historyIndex >= _history.length) {
      throw RangeError("History index $historyIndex out of bounds");
    }
    _value = _history[historyIndex];
    _controller.add(_value);
  }

  /// Disposes the [Flux], closing the stream and calling [onDispose].
  void dispose() {
    if (!_disposed) {
      _controller.close();
      _disposed = true;
      onDispose?.call();
    }
  }
}

/// A widget that rebuilds when a [Flux] state changes.
class FluxBuilder<T> extends StatelessWidget {
  final Flux<T> state;
  final Widget Function(BuildContext, T) builder;

  /// Creates a [FluxBuilder] that listens to [state] and builds with [builder].
  const FluxBuilder({required this.state, required this.builder, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: state.stream,
      initialData: state.value,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text("Error: ${snapshot.error}");
        return builder(context, snapshot.data as T);
      },
    );
  }
}