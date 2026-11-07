import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lockleaf/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce portrait orientation by default for security and predictable UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const LockLeafApp());
}
