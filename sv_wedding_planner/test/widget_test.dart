import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sv_wedding_planner/core/theme.dart';

// Committed so `flutter create` does not generate a default widget_test.dart
// that references a non-existent `MyApp`.
void main() {
  testWidgets('smoke: app theme renders a scaffold', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: Text('SV Wedding Planner'))),
      ),
    );
    expect(find.text('SV Wedding Planner'), findsOneWidget);
  });
}
