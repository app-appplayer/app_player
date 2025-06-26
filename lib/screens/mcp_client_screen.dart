import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';
import 'package:mcp_client/mcp_client.dart';
import '../models/server_config.dart';
import '../services/connection_manager.dart' as cm;
import '../services/runtime_manager.dart';

/// Screen that connects to an MCP server and renders its UI
class MCPClientScreen extends StatefulWidget {
  final ServerConfig server;

  const MCPClientScreen({super.key, required this.server});

  @override
  State<MCPClientScreen> createState() => _MCPClientScreenState();
}

class _MCPClientScreenState extends State<MCPClientScreen> {
  /// Connection manager instance
  late cm.ConnectionManager _connectionManager;
  
  /// Runtime manager instance
  late RuntimeManager _runtimeManager;
  
  /// Connection info for this screen
  cm.ConnectionInfo? _connection;
  
  /// Runtime instance for rendering UI - managed globally
  MCPUIRuntime? get _runtime => _runtimeManager.getRuntime(widget.server.id);
  
  /// Log messages for debugging
  final List<String> _logs = [];
  
  /// Show debug logs
  bool _showLogs = false;
  
  /// Stream subscription for connection state changes
  StreamSubscription? _connectionSubscription;
  
  /// Handle connection state changes
  void _onConnectionChanged() {
    if (mounted) {
      setState(() {
        // Update UI when connection state changes
      });
    }
  }
  
  /// Helper to add log messages
  void _log(String message) {
    if (kDebugMode) {
      stderr.writeln('[AppPlayer] $message');
    }
    if (mounted) {
      // Use addPostFrameCallback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _logs.add('[${DateTime.now().toIso8601String()}] $message');
            if (_logs.length > 100) {
              _logs.removeAt(0);
            }
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _connectionManager = context.read<cm.ConnectionManager>();
    _runtimeManager = context.read<RuntimeManager>();
    _connectToServer();
  }
  
  @override
  void dispose() {
    _connectionManager.removeListener(_onConnectionChanged);
    _connectionSubscription?.cancel();
    // Note: We don't destroy runtime here - it's managed globally
    // The connection is managed globally by ConnectionManager
    super.dispose();
  }
  
  /// Disconnect from server and go back
  Future<void> _disconnectAndGoBack() async {
    _log('User requested disconnect');
    
    // Clean up runtime through RuntimeManager
    _runtimeManager.removeRuntime(widget.server.id);
    
    // Disconnect through ConnectionManager
    await _connectionManager.disconnect(widget.server.id);
    
    // Go back to server list
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  
  
  /// Connect to the MCP server using ConnectionManager
  Future<void> _connectToServer() async {
    try {
      _log('Connecting to ${widget.server.name}...');
      
      // Get or create connection through ConnectionManager
      final result = await _connectionManager.connect(widget.server);
      if (!result.success) {
        throw Exception(result.error ?? 'Failed to connect');
      }
      _connection = result.connection;
      
      // Listen to connection state changes
      _connectionSubscription?.cancel();
      _connectionManager.addListener(_onConnectionChanged);
      
      // Wait for connection if still connecting
      if (_connection!.state == cm.ConnectionState.connecting) {
        _log('Waiting for connection to complete...');
        // Poll for connection state change
        while (_connection!.state == cm.ConnectionState.connecting) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      if (_connection!.state != cm.ConnectionState.connected) {
        throw Exception(_connection!.error ?? 'Failed to connect');
      }
      
      _log('Connected successfully!');
      
      // Setup notification handlers
      _setupNotificationHandlers();
      
      // Load the application
      await _loadApplication();
      
    } catch (e, stack) {
      _log('Failed to connect: $e');
      _log('Stack trace: $stack');
      _log('Transport config: ${widget.server.transportConfig}');
    }
  }
  
  /// Get the MCP client from the connection
  Client? get _mcpClient => _connection?.client;
  
  /// Get the current connection state
  ConnectionState get _connectionState {
    if (_connection == null) return ConnectionState.connecting;
    switch (_connection!.state) {
      case cm.ConnectionState.connecting:
        return ConnectionState.connecting;
      case cm.ConnectionState.connected:
        return ConnectionState.connected;
      case cm.ConnectionState.error:
        return ConnectionState.error;
    }
  }
  
  /// Get any error message
  String? get _error => _connection?.error;
  
  /// Load the application definition from the server
  Future<void> _loadApplication() async {
    if (_mcpClient == null) return;
    
    try {
      _log('Loading application...');
      
      // List available resources
      final resources = await _mcpClient!.listResources();
      _log('Available resources: ${resources.map((r) => r.uri).join(', ')}');
      
      // Try to find the main app resource
      String? appUri;
      for (final resource in resources) {
        if (resource.uri == 'ui://app' || 
            resource.uri.endsWith('/app') ||
            resource.name.toLowerCase().contains('app') ||
            resource.name.toLowerCase().contains('main')) {
          appUri = resource.uri;
          break;
        }
      }
      
      if (appUri == null && resources.isNotEmpty) {
        // Use the first UI resource
        appUri = resources.firstWhere(
          (r) => r.uri.startsWith('ui://'),
          orElse: () => resources.first,
        ).uri;
      }
      
      if (appUri == null) {
        throw Exception('No UI resources found on server');
      }
      
      _log('Loading resource: $appUri');
      
      // Read the resource
      final resource = await _mcpClient!.readResource(appUri);
      final content = resource.contents.first;
      final text = content.text;
      
      if (text == null) {
        throw Exception('No text content in resource');
      }
      
      // Parse the definition
      final definition = jsonDecode(text) as Map<String, dynamic>;
      _log('Loaded definition: ${definition['type']}');
      
      // Get or create runtime through RuntimeManager
      final runtime = _runtimeManager.getOrCreateRuntime(widget.server.id);
      
      // Only initialize if not already initialized
      if (!runtime.isInitialized) {
        await runtime.initialize(
          definition,
          pageLoader: (uri) async {
            _log('Loading page: $uri');
            final pageResource = await _mcpClient!.readResource(uri);
            final pageContent = pageResource.contents.first;
            final text = pageContent.text ?? '{}';
            return jsonDecode(text);
          },
        );
        
        _log('Application loaded successfully!');
      } else {
        _log('Application already loaded, reusing existing runtime');
      }
      
      // Update UI
      setState(() {});
      
    } catch (e) {
      _log('Failed to load application: $e');
      // Error is already stored in the connection object
    }
  }

  /// Handle tool calls from the UI
  Future<void> _handleToolCall(String tool, Map<String, dynamic> params) async {
    _log('Tool call: $tool with params: $params');
    
    
    if (_mcpClient == null) {
      _log('Cannot execute tool: not connected');
      return;
    }
    
    try {
      // Get available tools
      final tools = await _mcpClient!.listTools();
      final toolExists = tools.any((t) => t.name == tool);
      
      if (!toolExists) {
        _log('Tool not found: $tool');
        _log('Available tools: ${tools.map((t) => t.name).join(', ')}');
        throw Exception('Tool not found: $tool');
      }
      
      // Call the tool
      final result = await _mcpClient!.callTool(tool, params);
      _log('Tool result: ${result.content.length} content items');
      
      if (result.content.isNotEmpty) {
        final firstContent = result.content.first;
        if (firstContent is TextContent) {
          try {
            // Parse the response
            final responseData = jsonDecode(firstContent.text) as Map<String, dynamic>;
            _log('Parsed response: $responseData');
            
            // Update state
            if (_runtime?.isInitialized == true) {
              responseData.forEach((key, value) {
                _runtime!.stateManager.set(key, value);
                _log('Updated $key state to: $value');
              });
            }
            
          } catch (e) {
            _log('Failed to parse tool response: $e');
          }
        }
      }
      
    } catch (e) {
      _log('Tool execution failed: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tool failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Handle resource subscription
  Future<void> _handleResourceAction(String action, String resource, [String? binding]) async {
    _log('Resource $action called: $resource${binding != null ? ' -> $binding' : ''}');
    
    if (_mcpClient == null) {
      _log('Cannot execute resource action: not connected');
      return;
    }
    
    try {
      if (action == 'subscribe') {
        // Subscribe to the resource
        _log('Subscribing to: $resource');
        await _mcpClient!.subscribeResource(resource);
        _log('Successfully subscribed');
        
        // Register with runtime
        if (binding != null && _runtime?.isInitialized == true) {
          _runtime!.registerResourceSubscription(resource, binding);
          _log('Registered subscription mapping');
        }
        
        // Read initial data
        try {
          final resourceData = await _mcpClient!.readResource(resource);
          final content = resourceData.contents.first;
          final text = content.text;
          if (text != null) {
            final data = jsonDecode(text);
            _log('Initial resource data: $data');
            // Update state
            if (data is Map<String, dynamic>) {
              data.forEach((key, value) {
                _runtime!.stateManager.set(key, value);
              });
            }
          }
        } catch (e) {
          _log('Failed to read initial resource data: $e');
        }
      } else if (action == 'unsubscribe') {
        // Unsubscribe
        _log('Unsubscribing from: $resource');
        await _mcpClient!.unsubscribeResource(resource);
        _log('Successfully unsubscribed');
        
        // Remove from runtime
        if (_runtime?.isInitialized == true) {
          _runtime!.unregisterResourceSubscription(resource);
        }
      }
      
    } catch (e) {
      _log('Resource $action failed: $e');
    }
  }
  
  /// Setup notification handlers
  void _setupNotificationHandlers() {
    if (_mcpClient == null) return;
    
    _log('Setting up notification handlers...');
    
    // Register handler for resource updates
    _mcpClient!.onNotification('notifications/resources/updated', (params) async {
      _log('=== RESOURCE UPDATE NOTIFICATION ===');
      _log('Params: $params');
      
      if (_runtime?.isInitialized == true) {
        await _runtime!.handleNotification(
          {
            'method': 'notifications/resources/updated',
            'params': params,
          },
          resourceReader: (uri) async {
            final resource = await _mcpClient!.readResource(uri);
            return resource.contents.first.text ?? '{}';
          },
        );
      }
    });
    
    _log('Notification handlers ready');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.server.name),
          actions: [
          if (_connectionState == ConnectionState.connected)
            IconButton(
              icon: Icon(_showLogs ? Icons.code_off : Icons.code),
              onPressed: () => setState(() => _showLogs = !_showLogs),
              tooltip: 'Toggle logs',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _connectionState == ConnectionState.connecting 
                ? null 
                : _connectToServer,
            tooltip: 'Reconnect',
          ),
          if (_connectionState == ConnectionState.connected)
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              onPressed: _disconnectAndGoBack,
              tooltip: 'Disconnect',
              color: Colors.red,
            ),
        ],
        ),
        body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_showLogs) {
      return _buildLogsView();
    }
    
    switch (_connectionState) {
      case ConnectionState.connecting:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to server...'),
            ],
          ),
        );
        
      case ConnectionState.connected:
        if (_runtime?.isInitialized == true) {
          return _runtime!.buildUI(
            context: context,
            onToolCall: _handleToolCall,
            onResourceSubscribe: (uri, binding) async {
              await _handleResourceAction('subscribe', uri, binding);
            },
            onResourceUnsubscribe: (uri) async {
              await _handleResourceAction('unsubscribe', uri);
            },
          );
        }
        return const Center(
          child: Text('Loading application...'),
        );
        
      case ConnectionState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connection Failed',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _connectToServer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
        
    }
  }
  
  Widget _buildLogsView() {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade900,
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Debug Logs',
                  style: TextStyle(color: Colors.white, fontFamily: 'monospace'),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _logs.clear()),
                  icon: const Icon(Icons.clear, color: Colors.white),
                  iconSize: 18,
                  tooltip: 'Clear logs',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Text(
                  _logs[index],
                  style: const TextStyle(
                    color: Colors.green,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Connection states
enum ConnectionState {
  connecting,
  connected,
  error,
}