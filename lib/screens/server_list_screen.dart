import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:flutter_animate/flutter_animate.dart';
import '../models/server_config.dart';
import '../services/server_storage.dart';
import '../services/connection_manager.dart';
import '../widgets/server_card.dart';
import 'add_server_screen.dart';
import 'mcp_client_screen.dart';

/// Main screen showing the list of configured MCP servers
class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  List<ServerConfig> _servers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);
    try {
      final servers = await ServerStorage.getServers();
      setState(() {
        _servers = servers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load servers: $e')),
        );
      }
    }
  }

  Future<void> _deleteServer(ServerConfig server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Server'),
        content: Text('Are you sure you want to delete "${server.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ServerStorage.deleteServer(server.id);
      await _loadServers();
    }
  }

  Future<void> _toggleFavorite(ServerConfig server) async {
    await ServerStorage.toggleFavorite(server.id);
    await _loadServers();
  }

  Future<void> _connectToServer(ServerConfig server) async {
    await ServerStorage.updateLastConnected(server.id);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MCPClientScreen(server: server),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AppPlayer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _servers.isEmpty
              ? _buildEmptyState()
              : _buildServerList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddServerScreen(),
            ),
          );
          if (result == true) {
            await _loadServers();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Server'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 80,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No MCP Servers',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a server to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList() {
    return RefreshIndicator(
      onRefresh: _loadServers,
      child: Consumer<ConnectionManager>(
        builder: (context, connectionManager, child) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _servers.length,
            itemBuilder: (context, index) {
              final server = _servers[index];
              final connection = connectionManager.getConnection(server.id);
              final isConnected = connection?.isHealthy ?? false;
              
              return ServerCard(
                server: server,
                isConnected: isConnected,
                connectionState: connection?.state,
                onTap: () => _connectToServer(server),
                onEdit: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddServerScreen(server: server),
                    ),
                  );
                  if (result == true) {
                    await _loadServers();
                  }
                },
                onDelete: () => _deleteServer(server),
                onToggleFavorite: () => _toggleFavorite(server),
              );
            },
          );
        },
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'AppPlayer',
      applicationVersion: '1.0.0',
      applicationIcon: const FlutterLogo(size: 48),
      children: [
        const Text(
          'AppPlayer is a universal MCP client that connects to any MCP server and renders dynamic UIs using the Flutter MCP UI Runtime.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Powered by the Model Context Protocol (MCP) and Flutter.',
        ),
      ],
    );
  }
}