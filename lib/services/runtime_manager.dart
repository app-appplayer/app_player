import 'package:flutter/foundation.dart';
import 'package:flutter_mcp_ui_runtime/flutter_mcp_ui_runtime.dart';

/// Manages MCP UI Runtime instances for each connection
class RuntimeManager extends ChangeNotifier {
  /// Singleton instance
  static final RuntimeManager _instance = RuntimeManager._internal();
  
  /// Factory constructor returns singleton instance
  factory RuntimeManager() => _instance;
  
  /// Private constructor
  RuntimeManager._internal();
  
  /// Active runtimes mapped by server ID
  final Map<String, MCPUIRuntime> _runtimes = {};
  
  /// Get runtime for a server
  MCPUIRuntime? getRuntime(String serverId) => _runtimes[serverId];
  
  /// Check if runtime exists for a server
  bool hasRuntime(String serverId) => _runtimes.containsKey(serverId);
  
  /// Create or get runtime for a server
  MCPUIRuntime getOrCreateRuntime(String serverId) {
    if (_runtimes.containsKey(serverId)) {
      debugPrint('[RuntimeManager] Reusing existing runtime for server $serverId');
      return _runtimes[serverId]!;
    }
    
    debugPrint('[RuntimeManager] Creating new runtime for server $serverId');
    final runtime = MCPUIRuntime();
    _runtimes[serverId] = runtime;
    notifyListeners();
    
    return runtime;
  }
  
  /// Remove runtime for a server
  void removeRuntime(String serverId) {
    final runtime = _runtimes[serverId];
    if (runtime != null) {
      debugPrint('[RuntimeManager] Removing runtime for server $serverId');
      runtime.destroy();
      _runtimes.remove(serverId);
      notifyListeners();
    }
  }
  
  /// Remove all runtimes
  void removeAllRuntimes() {
    debugPrint('[RuntimeManager] Removing all runtimes');
    for (final runtime in _runtimes.values) {
      runtime.destroy();
    }
    _runtimes.clear();
    notifyListeners();
  }
}