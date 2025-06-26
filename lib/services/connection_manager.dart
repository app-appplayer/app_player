import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mcp_client/mcp_client.dart';
import '../models/server_config.dart';

/// Manages MCP client connections globally
class ConnectionManager extends ChangeNotifier {
  /// Singleton instance
  static final ConnectionManager _instance = ConnectionManager._internal();
  
  /// Factory constructor returns singleton instance
  factory ConnectionManager() => _instance;
  
  /// Private constructor
  ConnectionManager._internal();
  
  /// Active connections mapped by server ID
  final Map<String, ConnectionInfo> _connections = {};
  
  /// Get all active connections
  Map<String, ConnectionInfo> get connections => Map.unmodifiable(_connections);
  
  /// Check if a connection exists for a server
  bool hasConnection(String serverId) => _connections.containsKey(serverId);
  
  /// Get connection info for a server
  ConnectionInfo? getConnection(String serverId) => _connections[serverId];
  
  /// Connect to a server or return existing connection
  Future<ConnectionResult> connect(ServerConfig server) async {
    // Check if already connected
    if (_connections.containsKey(server.id)) {
      final existing = _connections[server.id]!;
      if (existing.state == ConnectionState.connected) {
        debugPrint('[ConnectionManager] Reusing existing connection for ${server.name}');
        return ConnectionResult.success(existing);
      } else if (existing.state == ConnectionState.connecting) {
        debugPrint('[ConnectionManager] Connection already in progress for ${server.name}');
        // Wait for existing connection attempt
        return _waitForConnection(server.id);
      }
    }
    
    // Create new connection
    debugPrint('[ConnectionManager] Creating new connection for ${server.name}');
    final info = ConnectionInfo(
      serverId: server.id,
      serverName: server.name,
      serverConfig: server,
      state: ConnectionState.connecting,
    );
    
    _connections[server.id] = info;
    // Notify listeners after the current build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    
    try {
      // Create client configuration
      final config = McpClient.simpleConfig(
        name: 'AppPlayer Client',
        version: '1.0.0',
        enableDebugLogging: kDebugMode,
      );
      
      // Create transport config
      final transportConfig = _createTransportConfig(server);
      
      // Connect to server
      final clientResult = await McpClient.createAndConnect(
        config: config,
        transportConfig: transportConfig,
      );
      
      if (clientResult.isFailure) {
        throw Exception('Failed to connect: ${clientResult.failureOrNull}');
      }
      
      final client = clientResult.get();
      
      // Update connection info
      info.client = client;
      info.state = ConnectionState.connected;
      info.connectedAt = DateTime.now();
      // Notify listeners after the current build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      
      debugPrint('[ConnectionManager] Successfully connected to ${server.name}');
      return ConnectionResult.success(info);
      
    } catch (e) {
      // Update connection state
      info.state = ConnectionState.error;
      info.error = e.toString();
      // Notify listeners after the current build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      
      debugPrint('[ConnectionManager] Failed to connect to ${server.name}: $e');
      return ConnectionResult.failure(e.toString());
    }
  }
  
  /// Disconnect from a server
  Future<void> disconnect(String serverId) async {
    final connection = _connections[serverId];
    if (connection == null) return;
    
    debugPrint('[ConnectionManager] Disconnecting from ${connection.serverName}');
    
    try {
      connection.client?.disconnect();
    } catch (e) {
      debugPrint('[ConnectionManager] Error during disconnect: $e');
    }
    
    _connections.remove(serverId);
    // Notify listeners after the current build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  /// Disconnect all connections
  Future<void> disconnectAll() async {
    debugPrint('[ConnectionManager] Disconnecting all connections');
    
    for (final connection in _connections.values) {
      try {
        connection.client?.disconnect();
      } catch (e) {
        debugPrint('[ConnectionManager] Error disconnecting ${connection.serverName}: $e');
      }
    }
    
    _connections.clear();
    // Notify listeners after the current build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  /// Reconnect to a server
  Future<ConnectionResult> reconnect(String serverId) async {
    final existingConnection = _connections[serverId];
    if (existingConnection == null) {
      return ConnectionResult.failure('No connection found for server');
    }
    
    final server = existingConnection.serverConfig;
    await disconnect(serverId);
    return connect(server);
  }
  
  /// Wait for an ongoing connection attempt
  Future<ConnectionResult> _waitForConnection(String serverId) async {
    const maxWait = Duration(seconds: 30);
    const checkInterval = Duration(milliseconds: 100);
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime) < maxWait) {
      final connection = _connections[serverId];
      if (connection == null) {
        return ConnectionResult.failure('Connection cancelled');
      }
      
      if (connection.state == ConnectionState.connected) {
        return ConnectionResult.success(connection);
      } else if (connection.state == ConnectionState.error) {
        return ConnectionResult.failure(connection.error ?? 'Connection failed');
      }
      
      await Future.delayed(checkInterval);
    }
    
    return ConnectionResult.failure('Connection timeout');
  }
  
  /// Create transport configuration from server config
  TransportConfig _createTransportConfig(ServerConfig server) {
    final config = server.transportConfig;
    
    switch (server.transportType) {
      case TransportType.stdio:
        return TransportConfig.stdio(
          command: config['command'] as String,
          arguments: (config['arguments'] as List<dynamic>?)?.cast<String>() ?? [],
          workingDirectory: config['workingDirectory'] as String?,
        );
        
      case TransportType.sse:
        return TransportConfig.sse(
          serverUrl: config['serverUrl'] as String,
          bearerToken: config['bearerToken'] as String?,
          enableCompression: config['enableCompression'] as bool? ?? false,
          heartbeatInterval: config['heartbeatInterval'] != null 
              ? Duration(seconds: config['heartbeatInterval'] as int)
              : null,
        );
        
      case TransportType.streamableHttp:
        return TransportConfig.streamableHttp(
          baseUrl: config['baseUrl'] as String,
          useHttp2: config['useHttp2'] as bool? ?? true,
          timeout: config['timeout'] != null
              ? Duration(seconds: config['timeout'] as int)
              : null,
        );
    }
  }
}

/// Connection state enum
enum ConnectionState {
  connecting,
  connected,
  error,
}

/// Information about an active connection
class ConnectionInfo {
  final String serverId;
  final String serverName;
  final ServerConfig serverConfig;
  ConnectionState state;
  Client? client;
  DateTime? connectedAt;
  String? error;
  
  ConnectionInfo({
    required this.serverId,
    required this.serverName,
    required this.serverConfig,
    required this.state,
    this.client,
    this.connectedAt,
    this.error,
  });
  
  /// Check if connection is healthy
  bool get isHealthy => state == ConnectionState.connected && client != null;
  
  /// Get connection duration
  Duration? get connectionDuration {
    if (connectedAt == null) return null;
    return DateTime.now().difference(connectedAt!);
  }
}

/// Result of a connection attempt
class ConnectionResult {
  final bool success;
  final ConnectionInfo? connection;
  final String? error;
  
  ConnectionResult._({
    required this.success,
    this.connection,
    this.error,
  });
  
  factory ConnectionResult.success(ConnectionInfo connection) {
    return ConnectionResult._(
      success: true,
      connection: connection,
    );
  }
  
  factory ConnectionResult.failure(String error) {
    return ConnectionResult._(
      success: false,
      error: error,
    );
  }
}