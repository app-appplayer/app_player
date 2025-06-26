import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_player/screens/server_list_screen.dart';
import 'package:app_player/services/server_storage.dart';
import 'package:app_player/services/connection_manager.dart';
import 'package:app_player/services/runtime_manager.dart';
import 'package:app_player/services/connection_health_monitor.dart';
import 'package:app_player/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage
  await ServerStorage.initialize();
  
  runApp(const AppPlayer());
}

/// AppPlayer - Universal MCP Client
/// 
/// Connect to any MCP server and render dynamic UIs through
/// the Flutter MCP UI Runtime.
class AppPlayer extends StatefulWidget {
  const AppPlayer({super.key});

  @override
  State<AppPlayer> createState() => _AppPlayerState();
}

class _AppPlayerState extends State<AppPlayer> with WidgetsBindingObserver {
  late final ConnectionManager _connectionManager;
  late final RuntimeManager _runtimeManager;
  late final ConnectionHealthMonitor _healthMonitor;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize managers
    _connectionManager = ConnectionManager();
    _runtimeManager = RuntimeManager();
    _healthMonitor = ConnectionHealthMonitor(_connectionManager);
    
    // Start health monitoring
    _healthMonitor.startMonitoring();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _healthMonitor.stopMonitoring();
    _connectionManager.disconnectAll();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    switch (state) {
      case AppLifecycleState.resumed:
        // Resume health monitoring when app comes to foreground
        _healthMonitor.startMonitoring();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Stop health monitoring when app goes to background
        _healthMonitor.stopMonitoring();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: _connectionManager,
        ),
        ChangeNotifierProvider.value(
          value: _runtimeManager,
        ),
      ],
      child: MaterialApp(
        title: 'AppPlayer',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const ServerListScreen(),
      ),
    );
  }
}