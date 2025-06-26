import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_config.dart';

/// Service for persisting server configurations
class ServerStorage {
  static const String _serversKey = 'mcp_servers';
  static late SharedPreferences _prefs;
  
  /// Initialize storage
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Get all saved server configurations
  static Future<List<ServerConfig>> getServers() async {
    final String? serversJson = _prefs.getString(_serversKey);
    if (serversJson == null) {
      // Add default demo servers on first run
      await _addDefaultServers();
      return getServers();
    }
    
    final List<dynamic> serversList = jsonDecode(serversJson) as List<dynamic>;
    return serversList
        .map((json) => ServerConfig.fromJson(json as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        // Sort by: favorites first, then by last connected, then by name
        if (a.isFavorite != b.isFavorite) {
          return a.isFavorite ? -1 : 1;
        }
        if (a.lastConnectedAt != null && b.lastConnectedAt != null) {
          return b.lastConnectedAt!.compareTo(a.lastConnectedAt!);
        }
        if (a.lastConnectedAt != null) return -1;
        if (b.lastConnectedAt != null) return 1;
        return a.name.compareTo(b.name);
      });
  }
  
  /// Save a server configuration
  static Future<void> saveServer(ServerConfig server) async {
    final servers = await getServers();
    final index = servers.indexWhere((s) => s.id == server.id);
    
    if (index >= 0) {
      servers[index] = server;
    } else {
      servers.add(server);
    }
    
    await _saveServers(servers);
  }
  
  /// Delete a server configuration
  static Future<void> deleteServer(String id) async {
    final servers = await getServers();
    servers.removeWhere((s) => s.id == id);
    await _saveServers(servers);
  }
  
  /// Update last connected time
  static Future<void> updateLastConnected(String id) async {
    final servers = await getServers();
    final index = servers.indexWhere((s) => s.id == id);
    
    if (index >= 0) {
      servers[index] = servers[index].copyWith(
        lastConnectedAt: DateTime.now(),
      );
      await _saveServers(servers);
    }
  }
  
  /// Toggle favorite status
  static Future<void> toggleFavorite(String id) async {
    final servers = await getServers();
    final index = servers.indexWhere((s) => s.id == id);
    
    if (index >= 0) {
      servers[index] = servers[index].copyWith(
        isFavorite: !servers[index].isFavorite,
      );
      await _saveServers(servers);
    }
  }
  
  /// Save servers to storage
  static Future<void> _saveServers(List<ServerConfig> servers) async {
    final serversJson = servers.map((s) => s.toJson()).toList();
    await _prefs.setString(_serversKey, jsonEncode(serversJson));
  }
  
  /// Add default demo servers on first run
  static Future<void> _addDefaultServers() async {
    final defaultServers = [
      ServerConfig(
        name: 'Demo MCP Server',
        description: 'Example server with counter, dashboard, and settings UIs',
        transportType: TransportType.stdio,
        transportConfig: {
          'command': 'dart',
          'arguments': ['run', 'bin/server.dart'],
          'workingDirectory': '/Users/jsha/Desktop/Works/workspace/mcp/makemind/servers/demo_mcp_server',
        },
        metadata: {
          'author': 'MCP UI Team',
          'version': '1.0.0',
          'capabilities': ['ui', 'tools', 'resources', 'notifications'],
        },
      ),
      ServerConfig(
        name: 'Weather Service',
        description: 'Real-time weather data and forecasts',
        transportType: TransportType.sse,
        transportConfig: {
          'serverUrl': 'https://api.weather-mcp.example.com/sse',
          'bearerToken': 'demo-token',
        },
        metadata: {
          'author': 'Weather MCP',
          'version': '2.1.0',
          'capabilities': ['ui', 'resources'],
        },
      ),
      ServerConfig(
        name: 'AI Assistant',
        description: 'GPT-powered assistant with chat interface',
        transportType: TransportType.streamableHttp,
        transportConfig: {
          'baseUrl': 'https://ai-mcp.example.com',
          'headers': {
            'User-Agent': 'AppPlayer/1.0',
          },
        },
        metadata: {
          'author': 'AI MCP',
          'version': '3.0.0',
          'capabilities': ['ui', 'tools', 'streaming'],
        },
      ),
    ];
    
    await _saveServers(defaultServers);
  }
}