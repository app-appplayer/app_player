import 'dart:async';
import 'package:flutter/foundation.dart';
import 'connection_manager.dart';

/// Monitors the health of MCP connections and handles auto-reconnection
class ConnectionHealthMonitor {
  final ConnectionManager _connectionManager;
  Timer? _healthCheckTimer;
  
  /// Health check interval
  static const Duration healthCheckInterval = Duration(seconds: 30);
  
  /// Maximum reconnection attempts
  static const int maxReconnectAttempts = 3;
  
  /// Delay between reconnection attempts
  static const Duration reconnectDelay = Duration(seconds: 5);
  
  /// Track reconnection attempts per server
  final Map<String, int> _reconnectAttempts = {};
  
  ConnectionHealthMonitor(this._connectionManager);
  
  /// Start monitoring connection health
  void startMonitoring() {
    stopMonitoring();
    
    // Initial health check
    _performHealthCheck();
    
    // Schedule periodic health checks
    _healthCheckTimer = Timer.periodic(
      healthCheckInterval,
      (_) => _performHealthCheck(),
    );
    
    debugPrint('ConnectionHealthMonitor: Started monitoring');
  }
  
  /// Stop monitoring connection health
  void stopMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    debugPrint('ConnectionHealthMonitor: Stopped monitoring');
  }
  
  /// Perform health check on all connections
  Future<void> _performHealthCheck() async {
    debugPrint('ConnectionHealthMonitor: Performing health check');
    
    // Handle any failed connections
    final connections = _connectionManager.connections.entries.toList();
    for (final entry in connections) {
      final serverId = entry.key;
      final connection = entry.value;
      
      if (connection.state == ConnectionState.error) {
        await _handleFailedConnection(serverId, connection);
      } else if (connection.state == ConnectionState.connected) {
        // Reset reconnect attempts on successful connection
        _reconnectAttempts[serverId] = 0;
      }
    }
  }
  
  /// Handle a failed connection
  Future<void> _handleFailedConnection(
    String serverId,
    ConnectionInfo connection,
  ) async {
    final attempts = _reconnectAttempts[serverId] ?? 0;
    
    if (attempts >= maxReconnectAttempts) {
      debugPrint(
        'ConnectionHealthMonitor: Max reconnection attempts reached for ${connection.serverName}',
      );
      return;
    }
    
    _reconnectAttempts[serverId] = attempts + 1;
    
    debugPrint(
      'ConnectionHealthMonitor: Attempting reconnection ${attempts + 1}/$maxReconnectAttempts for ${connection.serverName}',
    );
    
    // Wait before reconnecting
    await Future.delayed(reconnectDelay);
    
    try {
      await _connectionManager.reconnect(serverId);
      debugPrint(
        'ConnectionHealthMonitor: Successfully reconnected to ${connection.serverName}',
      );
    } catch (e) {
      debugPrint(
        'ConnectionHealthMonitor: Failed to reconnect to ${connection.serverName}: $e',
      );
    }
  }
  
  /// Reset reconnection attempts for a specific server
  void resetReconnectAttempts(String serverId) {
    _reconnectAttempts[serverId] = 0;
  }
  
  /// Get the number of reconnection attempts for a server
  int getReconnectAttempts(String serverId) {
    return _reconnectAttempts[serverId] ?? 0;
  }
}