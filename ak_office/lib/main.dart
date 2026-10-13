import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'database/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DatabaseService.initializeFfiIfRequired();

  runApp(
    const ProviderScope(
      child: DocuCraftApp(),
    ),
  );
}
