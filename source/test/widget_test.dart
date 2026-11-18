import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_manager/main.dart';

void main() {
  testWidgets('Internet Manager App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: InternetManagerApp()));
    await tester.pump();
    expect(find.byType(InternetManagerApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
