import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app_player/main.dart' as app;
import 'package:app_player/models/server_config.dart';
import 'package:app_player/services/server_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Demo MCP Server Integration Test', () {
    setUpAll(() async {
      // Initialize storage
      await ServerStorage.initialize();
      
      // Clear any existing servers
      final servers = await ServerStorage.getServers();
      for (final server in servers) {
        await ServerStorage.deleteServer(server.id);
      }
      
      // Add demo server configuration
      final demoServer = ServerConfig(
        name: 'Demo MCP Server (Test)',
        description: 'Integration test server',
        transportType: TransportType.stdio,
        transportConfig: {
          'command': 'dart',
          'arguments': ['run', 'bin/server.dart'],
          'workingDirectory': '/Users/jsha/Desktop/Works/workspace/mcp/makemind/servers/demo_mcp_server',
        },
      );
      
      await ServerStorage.saveServer(demoServer);
    });

    testWidgets('Connect to demo MCP server and render UI', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();
      
      // Verify we're on the server list screen
      expect(find.text('MCP Servers'), findsOneWidget);
      expect(find.text('Demo MCP Server (Test)'), findsOneWidget);
      
      // Tap on the demo server
      await tester.tap(find.text('Demo MCP Server (Test)'));
      await tester.pumpAndSettle();
      
      // Wait for connection (max 10 seconds)
      int attempts = 0;
      while (attempts < 20) {
        await tester.pump(const Duration(milliseconds: 500));
        
        // Check if we've connected and UI is rendered
        if (find.text('Counter').evaluate().isNotEmpty ||
            find.text('Dashboard').evaluate().isNotEmpty ||
            find.text('Settings').evaluate().isNotEmpty) {
          break;
        }
        
        attempts++;
      }
      
      // Verify connection was successful
      expect(find.text('Failed to connect').evaluate().isEmpty, true,
          reason: 'Should not show connection error');
      
      // Verify at least one UI element is rendered
      final hasUI = find.text('Counter').evaluate().isNotEmpty ||
                   find.text('Dashboard').evaluate().isNotEmpty ||
                   find.text('Settings').evaluate().isNotEmpty;
      
      expect(hasUI, true,
          reason: 'Should render at least one UI element from the server');
      
      // If counter UI is visible, test interaction
      if (find.text('Counter').evaluate().isNotEmpty) {
        // Find and tap increment button
        final incrementButton = find.byTooltip('Increment');
        if (incrementButton.evaluate().isNotEmpty) {
          await tester.tap(incrementButton);
          await tester.pump();
          
          // Verify counter incremented (looking for "1" or any number)
          expect(find.textContaining(RegExp(r'\d+')).evaluate().isNotEmpty, true,
              reason: 'Counter should show a number after increment');
        }
      }
    });
  });
}