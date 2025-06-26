import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Represents an MCP server configuration
class ServerConfig {
  final String id;
  final String name;
  final String description;
  final TransportType transportType;
  final Map<String, dynamic> transportConfig;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;
  final bool isFavorite;
  final Map<String, dynamic>? metadata;

  ServerConfig({
    String? id,
    required this.name,
    required this.description,
    required this.transportType,
    required this.transportConfig,
    DateTime? createdAt,
    this.lastConnectedAt,
    this.isFavorite = false,
    this.metadata,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Create from JSON
  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    // Handle transport type migration from old names
    final transportTypeString = json['transportType'] as String;
    TransportType transportType;
    
    // Map old transport type names to new ones
    switch (transportTypeString) {
      case 'tcp':
      case 'websocket':
        // Migrate TCP and WebSocket to SSE as the closest network transport
        transportType = TransportType.sse;
        break;
      case 'http':
        // Migrate HTTP to streamableHttp
        transportType = TransportType.streamableHttp;
        break;
      default:
        // Try to find exact match
        transportType = TransportType.values.firstWhere(
          (e) => e.name == transportTypeString,
          orElse: () => TransportType.stdio, // Default to stdio if unknown
        );
    }
    
    return ServerConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      transportType: transportType,
      transportConfig: json['transportConfig'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'] as String)
          : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'transportType': transportType.name,
      'transportConfig': transportConfig,
      'createdAt': createdAt.toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
      'isFavorite': isFavorite,
      'metadata': metadata,
    };
  }

  /// Create a copy with modifications
  ServerConfig copyWith({
    String? name,
    String? description,
    TransportType? transportType,
    Map<String, dynamic>? transportConfig,
    DateTime? lastConnectedAt,
    bool? isFavorite,
    Map<String, dynamic>? metadata,
  }) {
    return ServerConfig(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      transportType: transportType ?? this.transportType,
      transportConfig: transportConfig ?? this.transportConfig,
      createdAt: createdAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Supported transport types
enum TransportType {
  stdio,
  sse,
  streamableHttp,
}

/// Extension for transport type display
extension TransportTypeExtension on TransportType {
  String get displayName {
    switch (this) {
      case TransportType.stdio:
        return 'STDIO (Process)';
      case TransportType.sse:
        return 'SSE (Server-Sent Events)';
      case TransportType.streamableHttp:
        return 'HTTP (Streamable)';
    }
  }
  
  IconData get icon {
    switch (this) {
      case TransportType.stdio:
        return Icons.terminal;
      case TransportType.sse:
        return Icons.stream;
      case TransportType.streamableHttp:
        return Icons.http;
    }
  }
}

