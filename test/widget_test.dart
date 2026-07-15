import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/app_shell.dart';
import 'package:app/core/storage/app_storage.dart';
import 'package:app/features/sandbox/sandbox_controller.dart';
import 'package:app/features/sandbox/sandbox_models.dart';
import 'package:app/features/sandbox/sandbox_tray.dart';

void main() {
  testWidgets('chat shell renders key mobile surfaces', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ChattyMiniApp());

    expect(find.text('Tap anywhere to continue'), findsOneWidget);
    await tester.tap(find.text('Tap anywhere to continue'));
    await tester.pumpAndSettle();

    expect(find.text('Chatty-mini'), findsOneWidget);
    expect(find.text('Message the model...'), findsOneWidget);
    expect(find.text('Hot Context'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    expect(find.text('Help and About'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -1600));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Source Code'), findsOneWidget);
  });

  testWidgets('chat shell fits a short landscape phone viewport', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChattyMiniApp());
    await tester.tap(find.text('Tap anywhere to continue'));
    await tester.pumpAndSettle();

    expect(find.text('Chatty-mini'), findsOneWidget);
    expect(find.text('Message the model...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloud model editor closes without disposed controllers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ChattyMiniApp());
    await tester.tap(find.text('Tap anywhere to continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Models'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add cloud'));
    await tester.pumpAndSettle();
    expect(find.text('Add cloud model'), findsOneWidget);

    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(find.text('Add cloud model'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sandbox editor closes without disposed controllers', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _TestSandboxController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showSandboxTray(context: context, controller: controller),
            child: const Text('Open sandbox'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sandbox'));
    await tester.pumpAndSettle();
    expect(find.text('Sandbox Tray'), findsOneWidget);
    expect(find.byTooltip('Export lifecycle_test.md'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Edit sandbox file...'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Edit sandbox file...'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _TestSandboxController extends SandboxController {
  _TestSandboxController() : super(storage: AppStorageService());

  @override
  List<SandboxFileEntry> get files => [
    SandboxFileEntry(
      relativePath: 'lifecycle_test.md',
      fileType: 'markdown',
      sizeBytes: 12,
      modifiedAt: DateTime(2026, 7, 15),
    ),
  ];

  @override
  Future<String> readFile(String relativePath) async => '# Test\n';
}
