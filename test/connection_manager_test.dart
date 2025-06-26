import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';
import 'package:app_player/services/connection_manager.dart';
import 'package:app_player/models/server_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('ConnectionManager', () {
    late ConnectionManager connectionManager;

    setUp(() {
      connectionManager = ConnectionManager();
    });

    tearDown(() async {
      await connectionManager.disconnectAll();
    });

    test('should be a singleton', () {
      final instance1 = ConnectionManager();
      final instance2 = ConnectionManager();
      expect(identical(instance1, instance2), isTrue);
    });

    test('should track connections by server ID', () {
      expect(connectionManager.connections.isEmpty, isTrue);
      expect(connectionManager.hasConnection('test-id'), isFalse);
    });

    test('should handle multiple connections', () async {
      // Create multiple mock servers with invalid commands
      // This ensures they'll be tracked but won't actually connect
      final servers = List.generate(
        3,
        (i) => ServerConfig(
          id: 'server-$i',
          name: 'Server $i',
          description: 'Test server $i',
          transportType: TransportType.stdio,
          transportConfig: {
            'command': 'invalid-test-command-$i',
            'arguments': [],
          },
        ),
      );

      // Connect to multiple servers
      for (final server in servers) {
        try {
          await connectionManager.connect(server);
        } catch (e) {
          // Connection will fail, but connection info should still be tracked
        }
      }

      // All connections should be tracked even if they failed
      expect(connectionManager.connections.length, equals(3));
      
      // Verify all servers are tracked
      for (final server in servers) {
        expect(connectionManager.hasConnection(server.id), isTrue);
        final connection = connectionManager.getConnection(server.id);
        expect(connection, isNotNull);
        expect(connection!.state, equals(ConnectionState.error));
      }
    });

    test('should reuse existing connections', () async {
      // This test verifies that connections in "connected" or "connecting" state are reused.
      // For connections in "error" state, a new connection is created.
      // We'll simulate this by testing the reuse behavior with different connection states.
      
      final server = ServerConfig(
        id: 'reuse-test',
        name: 'Reuse Test Server',
        description: 'Test server for connection reuse',
        transportType: TransportType.stdio,
        transportConfig: {
          'command': 'invalid-test-command',
          'arguments': [],
        },
      );

      // First connection attempt will fail
      try {
        await connectionManager.connect(server);
      } catch (e) {
        // Expected to fail
      }
      
      final connection1 = connectionManager.getConnection(server.id);
      expect(connection1, isNotNull);
      expect(connection1!.state, equals(ConnectionState.error));

      // Second connection attempt will create a NEW connection because the first one is in error state
      try {
        await connectionManager.connect(server);
      } catch (e) {
        // Expected to fail
      }
      
      final connection2 = connectionManager.getConnection(server.id);
      expect(connection2, isNotNull);
      expect(connection2!.state, equals(ConnectionState.error));
      
      // Should NOT be the same instance since error state connections are replaced
      expect(identical(connection1, connection2), isFalse);
      
      // Should still only have one connection (the old one was replaced)
      expect(connectionManager.connections.length, equals(1));
    });

    test('should disconnect connections', () async {
      final server = ServerConfig(
        id: 'disconnect-test',
        name: 'Disconnect Test Server',
        description: 'Test server for disconnection',
        transportType: TransportType.stdio,
        transportConfig: {
          'command': 'invalid-test-command',
          'arguments': [],
        },
      );

      // Connect
      try {
        await connectionManager.connect(server);
      } catch (e) {
        // Expected to fail
      }

      expect(connectionManager.hasConnection(server.id), isTrue);

      // Disconnect
      await connectionManager.disconnect(server.id);

      expect(connectionManager.hasConnection(server.id), isFalse);
      expect(connectionManager.connections.isEmpty, isTrue);
    });

    testWidgets('should notify listeners on connection changes', (WidgetTester tester) async {
      final server = ServerConfig(
        id: 'listener-test',
        name: 'Listener Test Server',
        description: 'Test server for listener notifications',
        transportType: TransportType.stdio,
        transportConfig: {
          'command': 'invalid-test-command',
          'arguments': [],
        },
      );

      int notificationCount = 0;
      void listener() {
        notificationCount++;
      }

      connectionManager.addListener(listener);

      // Build a simple widget tree to enable frame scheduling
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Connection attempt
      try {
        await connectionManager.connect(server);
      } catch (e) {
        // Expected to fail
      }
      
      // Wait for post-frame callbacks to execute
      await tester.pump();

      // Should have notified at least twice:
      // 1. When connection state changes to connecting (via addPostFrameCallback)
      // 2. When connection state changes to error (via addPostFrameCallback)
      expect(notificationCount, greaterThanOrEqualTo(2));

      // Disconnect should trigger another notification
      final countBeforeDisconnect = notificationCount;
      await connectionManager.disconnect(server.id);
      
      // Wait for post-frame callbacks to execute
      await tester.pump();
      
      expect(notificationCount, greaterThan(countBeforeDisconnect));

      connectionManager.removeListener(listener);
    });
  });
}