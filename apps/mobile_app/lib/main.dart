import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/creator_app.dart';
import 'bootstrap/bootstrap.dart';

void main() async {
  try {
    await AppBootstrap.initialize();
  } catch (e, st) {
    debugPrint('[bootstrap] initialize failed: $e\n$st');
    runApp(_BootstrapFailedApp(message: e.toString()));
    return;
  }

  runApp(
    const ProviderScope(
      child: CreatorApp(),
    ),
  );
}

/// Shown when compile-time env is missing so TestFlight is not a dead splash.
class _BootstrapFailedApp extends StatelessWidget {
  const _BootstrapFailedApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'App failed to start.\n\n$message',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
