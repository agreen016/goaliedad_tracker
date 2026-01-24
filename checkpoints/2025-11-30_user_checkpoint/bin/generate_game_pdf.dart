// This is a helper that demonstrates a purely-Dart approach would require
// refactoring the PDF builder to not depend on Flutter's image codecs and
// dart:ui types; kept here as a note and placeholder for users who want an
// offline generator that reads pre-captured rink/heatmap PNGs from disk.

import 'dart:io';

void main(List<String> args) {
  print(
    'This helper requires pre-captured PNGs; run the app and use the Export button instead.',
  );
}
