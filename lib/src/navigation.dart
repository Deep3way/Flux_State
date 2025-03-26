import 'package:flutter/material.dart';

/// Simple navigation utilities for Flutter apps using [FluxState].
class FluxNavigator {
  /// Pushes a new [page] onto the navigation stack.
  static void to(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// Replaces the current page with a new [page].
  static void replace(BuildContext context, Widget page) {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  /// Pops the current page off the navigation stack.
  static void back(BuildContext context) {
    Navigator.of(context).pop();
  }
}