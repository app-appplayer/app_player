import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_client/mcp_client.dart';

void main() {
  group('MCP Connection Test', () {
    test('Connect to demo MCP server via STDIO', skip: 'Requires actual MCP server running', () async {
      // Create client configuration
      final config = McpClient.simpleConfig(
        name: 'Test Client',
        version: '1.0.0',
        enableDebugLogging: true,
      );

      // Create transport configuration for demo server
      final transportConfig = TransportConfig.stdio(
        command: 'dart',
        arguments: ['run', 'bin/server.dart'],
        workingDirectory: '/Users/jsha/Desktop/Works/workspace/mcp/makemind/servers/demo_mcp_server',
      );
      
      // Create and connect client
      final clientResult = await McpClient.createAndConnect(
        config: config,
        transportConfig: transportConfig,
      );
      
      // Verify connection succeeded
      expect(clientResult.isSuccess, true, 
          reason: 'Should connect successfully');
      
      final client = clientResult.fold(
        (c) => c,
        (error) => throw Exception('Failed to connect: $error'),
      );
      
      // List available resources
      final resources = await client.listResources();
      print('Available resources:');
      for (final resource in resources) {
        print('  - ${resource.uri}: ${resource.name}');
      }
      
      // Verify resources are available
      expect(resources.isNotEmpty, true,
          reason: 'Server should provide resources');
      
      // Find UI resource
      final uiResource = resources.firstWhere(
        (r) => r.uri.startsWith('ui://'),
        orElse: () => resources.first,
      );
      
      print('\nReading UI resource: ${uiResource.uri}');
      
      // Read the UI resource
      final resourceContent = await client.readResource(uiResource.uri);
      expect(resourceContent.contents.isNotEmpty, true,
          reason: 'Resource should have content');
      
      final content = resourceContent.contents.first;
      final text = content.text;
      expect(text, isNotNull,
          reason: 'Resource should have text content');
      
      print('UI definition length: ${text!.length} characters');
      
      // Verify content structure
      print('Content type: ${content.runtimeType}');
      print('Content has text: ${content.text != null}');
      
      // List tools
      final tools = await client.listTools();
      print('\nAvailable tools:');
      for (final tool in tools) {
        print('  - ${tool.name}: ${tool.description}');
      }
      
      // Disconnect
      client.disconnect();
      print('\nTest completed successfully!');
    });
  });
}