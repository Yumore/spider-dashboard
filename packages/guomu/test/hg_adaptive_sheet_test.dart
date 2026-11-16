import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/widgets/hg_adaptive_sheet.dart';

void main() {
  testWidgets('adaptive sheet supports simple and scrollable content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showHgAdaptiveSheet<void>(
                    context,
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('sheet content'),
                    ),
                  ),
                  child: const Text('open'),
                ),
                TextButton(
                  onPressed: () => showHgAdaptiveSheetBuilder<void>(
                    context,
                    childScrollable: true,
                    builder: (_) => ListView.builder(
                      itemCount: 30,
                      itemBuilder: (_, index) =>
                          ListTile(title: Text('row $index')),
                    ),
                  ),
                  child: const Text('open list'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('sheet content'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open list'));
    await tester.pumpAndSettle();
    expect(find.text('row 0'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
