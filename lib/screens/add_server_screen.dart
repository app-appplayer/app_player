import 'package:flutter/material.dart';
import '../models/server_config.dart';
import '../services/server_storage.dart';

/// Screen for adding or editing a server configuration
class AddServerScreen extends StatefulWidget {
  final ServerConfig? server;

  const AddServerScreen({super.key, this.server});

  @override
  State<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends State<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late TransportType _selectedTransportType;
  
  // Transport-specific controllers
  final Map<String, TextEditingController> _transportControllers = {};
  
  bool get isEditing => widget.server != null;

  @override
  void initState() {
    super.initState();
    
    _nameController = TextEditingController(text: widget.server?.name);
    _descriptionController = TextEditingController(text: widget.server?.description);
    _selectedTransportType = widget.server?.transportType ?? TransportType.stdio;
    
    // Initialize transport config
    if (widget.server != null) {
      widget.server!.transportConfig.forEach((key, value) {
        _transportControllers[key] = TextEditingController(text: value.toString());
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final controller in _transportControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Server' : 'Add Server'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Server Name',
                hintText: 'My MCP Server',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a server name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What does this server do?',
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<TransportType>(
              value: _selectedTransportType,
              decoration: const InputDecoration(
                labelText: 'Transport Type',
              ),
              items: TransportType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(type.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(type.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTransportType = value;
                    _transportControllers.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            ..._buildTransportFields(),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _saveServer,
                    child: Text(isEditing ? 'Update' : 'Add Server'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTransportFields() {
    switch (_selectedTransportType) {
      case TransportType.stdio:
        return _buildStdioFields();
      case TransportType.sse:
        return _buildSseFields();
      case TransportType.streamableHttp:
        return _buildStreamableHttpFields();
    }
  }

  List<Widget> _buildStdioFields() {
    _transportControllers['command'] ??= TextEditingController();
    _transportControllers['arguments'] ??= TextEditingController();
    _transportControllers['workingDirectory'] ??= TextEditingController();

    return [
      TextFormField(
        controller: _transportControllers['command'],
        decoration: const InputDecoration(
          labelText: 'Command',
          hintText: 'dart, python, node, etc.',
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a command';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _transportControllers['arguments'],
        decoration: const InputDecoration(
          labelText: 'Arguments',
          hintText: 'run bin/server.dart',
          helperText: 'Space-separated arguments',
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _transportControllers['workingDirectory'],
        decoration: const InputDecoration(
          labelText: 'Working Directory',
          hintText: '../my_mcp_server',
          helperText: 'Relative to AppPlayer directory',
        ),
      ),
    ];
  }

  List<Widget> _buildSseFields() {
    _transportControllers['serverUrl'] ??= TextEditingController();
    _transportControllers['bearerToken'] ??= TextEditingController();
    _transportControllers['enableCompression'] ??= TextEditingController(text: 'false');
    _transportControllers['heartbeatInterval'] ??= TextEditingController();

    return [
      TextFormField(
        controller: _transportControllers['serverUrl'],
        decoration: const InputDecoration(
          labelText: 'Server URL',
          hintText: 'https://api.example.com/sse',
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a server URL';
          }
          if (!Uri.tryParse(value)!.isAbsolute) {
            return 'Please enter a valid URL';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _transportControllers['bearerToken'],
        decoration: const InputDecoration(
          labelText: 'Bearer Token (Optional)',
          hintText: 'your-bearer-token',
        ),
        obscureText: true,
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Enable Compression'),
        value: _transportControllers['enableCompression']!.text == 'true',
        onChanged: (value) {
          setState(() {
            _transportControllers['enableCompression']!.text = value.toString();
          });
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _transportControllers['heartbeatInterval'],
        decoration: const InputDecoration(
          labelText: 'Heartbeat Interval (seconds, optional)',
          hintText: '30',
        ),
        keyboardType: TextInputType.number,
      ),
    ];
  }

  List<Widget> _buildStreamableHttpFields() {
    _transportControllers['baseUrl'] ??= TextEditingController();
    _transportControllers['useHttp2'] ??= TextEditingController(text: 'true');
    _transportControllers['timeout'] ??= TextEditingController(text: '30');

    return [
      TextFormField(
        controller: _transportControllers['baseUrl'],
        decoration: const InputDecoration(
          labelText: 'Base URL',
          hintText: 'https://api.example.com',
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a base URL';
          }
          if (!Uri.tryParse(value)!.isAbsolute) {
            return 'Please enter a valid URL';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      SwitchListTile(
        title: const Text('Use HTTP/2'),
        value: _transportControllers['useHttp2']!.text == 'true',
        onChanged: (value) {
          setState(() {
            _transportControllers['useHttp2']!.text = value.toString();
          });
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _transportControllers['timeout'],
        decoration: const InputDecoration(
          labelText: 'Timeout (seconds)',
          hintText: '30',
        ),
        keyboardType: TextInputType.number,
      ),
    ];
  }

  Future<void> _saveServer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Build transport config
    final transportConfig = <String, dynamic>{};
    
    switch (_selectedTransportType) {
      case TransportType.stdio:
        transportConfig['command'] = _transportControllers['command']!.text;
        final args = _transportControllers['arguments']!.text;
        if (args.isNotEmpty) {
          transportConfig['arguments'] = args.split(' ');
        }
        final workDir = _transportControllers['workingDirectory']!.text;
        if (workDir.isNotEmpty) {
          transportConfig['workingDirectory'] = workDir;
        }
        break;
      case TransportType.sse:
        transportConfig['serverUrl'] = _transportControllers['serverUrl']!.text;
        final bearerToken = _transportControllers['bearerToken']!.text;
        if (bearerToken.isNotEmpty) {
          transportConfig['bearerToken'] = bearerToken;
        }
        transportConfig['enableCompression'] = _transportControllers['enableCompression']!.text == 'true';
        final heartbeat = _transportControllers['heartbeatInterval']!.text;
        if (heartbeat.isNotEmpty) {
          transportConfig['heartbeatInterval'] = int.parse(heartbeat);
        }
        break;
      case TransportType.streamableHttp:
        transportConfig['baseUrl'] = _transportControllers['baseUrl']!.text;
        transportConfig['useHttp2'] = _transportControllers['useHttp2']!.text == 'true';
        transportConfig['timeout'] = int.parse(_transportControllers['timeout']!.text);
        break;
    }

    // Create or update server config
    final server = ServerConfig(
      id: widget.server?.id,
      name: _nameController.text,
      description: _descriptionController.text,
      transportType: _selectedTransportType,
      transportConfig: transportConfig,
      createdAt: widget.server?.createdAt,
      lastConnectedAt: widget.server?.lastConnectedAt,
      isFavorite: widget.server?.isFavorite ?? false,
      metadata: widget.server?.metadata,
    );

    await ServerStorage.saveServer(server);
    
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}