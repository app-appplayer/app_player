import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_player/main.dart';
import 'package:app_player/services/server_storage.dart';

void main() {
  testWidgets('AppPlayer shows server list screen', (WidgetTester tester) async {
    // Initialize storage
    await ServerStorage.initialize();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AppPlayer());
    
    // Instead of pumpAndSettle, just pump a few frames
    // This avoids issues with the ConnectionHealthMonitor timer
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify AppPlayer title is shown
    expect(find.text('AppPlayer'), findsOneWidget);
    
    // Verify Add Server button exists
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}