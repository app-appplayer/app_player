import 'package:flutter/material.dart';
import '../models/server_config.dart';
import '../services/connection_manager.dart' as cm;

/// Card widget for displaying a server configuration
class ServerCard extends StatelessWidget {
  final ServerConfig server;
  final bool isConnected;
  final cm.ConnectionState? connectionState;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const ServerCard({
    super.key,
    required this.server,
    this.isConnected = false,
    this.connectionState,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    server.transportType.icon,
                    size: 24,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                server.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (server.isFavorite)
                              Icon(
                                Icons.star,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          server.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'favorite':
                          onToggleFavorite();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'favorite',
                        child: Row(
                          children: [
                            Icon(server.isFavorite
                                ? Icons.star_border
                                : Icons.star),
                            const SizedBox(width: 8),
                            Text(server.isFavorite
                                ? 'Remove from favorites'
                                : 'Add to favorites'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.cable,
                    label: server.transportType.displayName,
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  if (server.lastConnectedAt != null)
                    _buildInfoChip(
                      icon: Icons.access_time,
                      label: _formatLastConnected(server.lastConnectedAt!),
                      theme: theme,
                    ),
                  const SizedBox(width: 8),
                  if (connectionState != null)
                    _buildConnectionStatus(theme),
                  const Spacer(),
                  if (server.metadata?['version'] != null)
                    Text(
                      'v${server.metadata!['version']}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastConnected(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }
  
  Widget _buildConnectionStatus(ThemeData theme) {
    final String label;
    final Color color;
    final IconData icon;
    
    switch (connectionState) {
      case cm.ConnectionState.connected:
        label = 'Connected';
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case cm.ConnectionState.connecting:
        label = 'Connecting';
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case cm.ConnectionState.error:
        label = 'Error';
        color = Colors.red;
        icon = Icons.error;
        break;
      case null:
        label = 'Disconnected';
        color = theme.colorScheme.onSurfaceVariant;
        icon = Icons.circle_outlined;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}