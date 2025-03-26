import 'dart:async';
import 'package:flutter/material.dart';

class Flux<T> {
  T _value;
  final StreamController<T> _controller = StreamController.broadcast();
  final List<T> _history = [];
  bool _disposed = false;
  final VoidCallback? onInit;
  final VoidCallback? onDispose;

  Flux(this._value, {this.onInit, this.onDispose}) {
    _history.add(_value);
    onInit?.call();
  }

  T get value => _disposed ? throw StateError("Flux is disposed") : _value;

  set value(T newValue) {
    if (_disposed) throw StateError("Cannot set value on disposed Flux");
    _value = newValue;
    _history.add(_value);
    _controller.add(_value);
  }

  void update(T Function(T) updater) {
    if (_disposed) throw StateError("Cannot update disposed Flux");
    _value = updater(_value);
    _history.add(_value);
    _controller.add(_value);
  }

  Stream<T> get stream => _controller.stream;

  Flux<T> get obs => this;

  Flux<R> computed<R>(R Function(T) computeFn) {
    final computedFlux = Flux<R>(computeFn(_value));
    stream.listen((value) {
      if (!_disposed) computedFlux.value = computeFn(value);
    });
    return computedFlux;
  }

  List<T> get history => List.unmodifiable(_history);

  void revert(int historyIndex) {
    if (_disposed) throw StateError("Cannot revert disposed Flux");
    if (historyIndex < 0 || historyIndex >= _history.length) {
      throw RangeError("History index $historyIndex out of bounds");
    }
    _value = _history[historyIndex];
    _controller.add(_value);
  }

  void dispose() {
    if (!_disposed) {
      _controller.close();
      _disposed = true;
      onDispose?.call();
    }
  }
}

class FluxBuilder<T> extends StatelessWidget {
  final Flux<T> state;
  final Widget Function(BuildContext, T) builder;

  const FluxBuilder({required this.state, required this.builder, Key? key}) : super(key: key);

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