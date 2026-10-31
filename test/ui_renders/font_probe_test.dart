/// Font probe: verifies the MiSans subset loads under `flutter test` and that
/// CJK glyphs resolve through the family (visual: real glyphs vs box glyphs).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Golden against a macOS-generated PNG (see dart_test.yaml) — excluded on
  // CI like the screen renders.
  testWidgets('FontManifest lists MiSans and CJK glyphs render', (
    WidgetTester tester,
  ) async {
    final ByteData manifest = await rootBundle.load('FontManifest.json');
    debugPrint('MANIFEST: ${utf8.decode(manifest.buffer.asUint8List())}');

    final ByteData data = await rootBundle.load(
      'assets/fonts/MiSans-Regular.ttf',
    );
    debugPrint('FONT BYTES: ${data.lengthInBytes}');
    // Load all four weights exactly like the render harness does.
    final List<Future<ByteData>> faces = <Future<ByteData>>[
      rootBundle.load('assets/fonts/MiSans-Regular.ttf'),
      rootBundle.load('assets/fonts/MiSans-Medium.ttf'),
      rootBundle.load('assets/fonts/MiSans-Demibold.ttf'),
      rootBundle.load('assets/fonts/MiSans-Bold.ttf'),
    ];
    final FontLoader loader = FontLoader('MiSans');
    for (final Future<ByteData> face in faces) {
      loader.addFont(face);
    }
    await loader.load();

    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredBox(
          color: Colors.white,
          child: Column(
            children: <Widget>[
              Text('今日汇总 1935', style: TextStyle(fontFamily: 'MiSans')),
              Text('今日汇总 1935'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/font_probe.png'),
    );
  }, tags: 'ui-renders');
}
