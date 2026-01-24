import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:goaliedad_tracker/services/pdf_export_service.dart';

// Simple runner to generate a sample PDF for the first game in the Hive box.
Future<void> main() async {
  // This file is intended to be run in a Flutter context (desktop/mobile) to
  // exercise the in-app PDF generation. It is not runnable as a pure Dart CLI
  // due to dependencies on flutter bindings.
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Run the export from inside the app')),
      ),
    ),
  );
}
