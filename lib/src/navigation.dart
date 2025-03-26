import 'package:flutter/material.dart';

class FluxNavigator {
  static void to(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  static void replace(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  static void back(BuildContext context) {
    Navigator.of(context).pop();
  }
}