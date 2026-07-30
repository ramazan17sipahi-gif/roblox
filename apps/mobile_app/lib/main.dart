import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/creator_app.dart';
import 'bootstrap/bootstrap.dart';

void main() async {
  await AppBootstrap.initialize();

  runApp(
    const ProviderScope(
      child: CreatorApp(),
    ),
  );
}
