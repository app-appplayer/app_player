# AppPlayer

## 🙌 Support This Project

If you find this package useful, consider supporting ongoing development on PayPal.

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/ncp/payment/F7G56QD9LSJ92)  
Support makemind via [PayPal](https://www.paypal.com/ncp/payment/F7G56QD9LSJ92)

---

### 🔗 MCP Dart Package Family

- [`mcp_server`](https://pub.dev/packages/mcp_server): Exposes tools, resources, and prompts to LLMs. Acts as the AI server.
- [`mcp_client`](https://pub.dev/packages/mcp_client): Connects Flutter/Dart apps to MCP servers. Acts as the client interface.
- [`mcp_llm`](https://pub.dev/packages/mcp_llm): Bridges LLMs (Claude, OpenAI, etc.) to MCP clients/servers. Acts as the LLM brain.
- [`flutter_mcp`](https://pub.dev/packages/flutter_mcp): Complete Flutter plugin for MCP integration with platform features.
- [`flutter_mcp_ui_core`](https://pub.dev/packages/flutter_mcp_ui_core): Core models, constants, and utilities for Flutter MCP UI system. 
- [`flutter_mcp_ui_runtime`](https://pub.dev/packages/flutter_mcp_ui_runtime): Comprehensive runtime for building dynamic, reactive UIs through JSON specifications.
- [`flutter_mcp_ui_generator`](https://pub.dev/packages/flutter_mcp_ui_generator): JSON generation toolkit for creating UI definitions with templates and fluent API. 

---

AppPlayer is a universal MCP (Model Context Protocol) client that can connect to any MCP server and render dynamic UIs using the Flutter MCP UI Runtime.

## Features

- **Universal MCP Client**: Connect to any MCP server regardless of its implementation
- **Multiple Transport Types**: Support for STDIO, SSE, and Streamable HTTP transports
- **Dynamic UI Rendering**: Renders UI definitions from MCP servers using the MCP UI DSL v1.0 specification
- **Server Management**: Save, edit, and organize multiple server configurations
- **Navigation State Persistence**: Maintains navigation state across app lifecycle changes
- **Connection Health Monitoring**: Automatic reconnection and health checks for connections
- **Real-time Runtime Management**: Manage multiple MCP runtime instances simultaneously
- **Tool Execution**: Execute server-side tools with parameters through the runtime
- **Persistent Storage**: Server configurations are saved locally using SharedPreferences

## Getting Started

### Prerequisites

- Flutter SDK 3.0.0 or higher
- Dart SDK
- An MCP server to connect to

### Installation

1. Clone the repository:
```bash
git clone https://github.com/app-appplayer/app_player.git
cd app_player
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building the App

**Important**: When building AppPlayer for release, you must use the `--no-tree-shake-icons` flag to ensure dynamic icons work properly:

```bash
flutter build apk --no-tree-shake-icons
flutter build ios --no-tree-shake-icons
flutter build macos --no-tree-shake-icons
flutter build windows --no-tree-shake-icons
flutter build linux --no-tree-shake-icons
```

This is necessary because AppPlayer renders UI dynamically from JSON, including icon names like `"icon": "folder"`. Without this flag, Material Icons will be removed during compilation and icons won't appear in the UI.

## Usage

### Adding a Server

1. Click the "Add Server" floating action button on the main screen
2. Enter server details:
   - **Name**: A friendly name for the server
   - **Description**: What the server does (optional)
   - **Transport Type**: Choose the connection method
   - **Transport Config**: Enter connection details based on the transport type

### Transport Configuration

#### STDIO (Process)
- **Command**: The executable to run (e.g., `dart`, `python`, `node`)
- **Arguments**: Command line arguments (one per line)
- **Working Directory**: Where to run the command from (optional)

#### SSE (Server-Sent Events)
- **Server URL**: The SSE endpoint URL
- **Bearer Token**: Optional authentication token
- **Enable Compression**: Toggle for response compression
- **Heartbeat Interval**: Keep-alive interval in seconds (optional)

#### Streamable HTTP
- **Base URL**: The HTTP server's base URL
- **Use HTTP/2**: Enable HTTP/2 protocol
- **Timeout**: Request timeout in seconds (optional)

### Connecting to a Server

1. Tap on a server card to connect
2. AppPlayer will:
   - Establish connection using the configured transport
   - Initialize the MCP UI Runtime
   - Render the server's UI dynamically
3. Interact with the UI - all actions are handled through the runtime and server

### Managing Servers

- **Edit**: Long-press on a server card and tap the edit icon
- **Delete**: Long-press on a server card and tap the delete icon
- **Connection Status**: View connection state in real-time on each card

## Architecture

AppPlayer follows a clean architecture pattern with service-based state management:

```
lib/
├── models/          # Data models
│   └── server_config.dart
├── screens/         # UI screens
│   ├── server_list_screen.dart
│   ├── add_server_screen.dart
│   └── mcp_client_screen.dart
├── services/        # Business logic and state management
│   ├── connection_manager.dart    # Global connection management
│   ├── runtime_manager.dart       # MCP UI Runtime management
│   ├── server_storage.dart        # Persistent storage
│   └── connection_health_monitor.dart
├── widgets/         # Reusable UI components
│   └── server_card.dart
└── theme/          # App theming
    └── app_theme.dart
```

### Key Components

1. **ConnectionManager**: Singleton service managing all MCP client connections
   - Tracks connection states (connecting, connected, error)
   - Reuses existing connections when possible
   - Notifies listeners of connection changes

2. **RuntimeManager**: Manages MCP UI Runtime instances
   - Creates and tracks runtime instances per server
   - Handles runtime lifecycle and cleanup

3. **ServerStorage**: Persists server configurations
   - Uses SharedPreferences for local storage
   - Loads servers on app startup
   - Supports add, update, and delete operations

4. **ConnectionHealthMonitor**: Monitors connection health
   - Periodic health checks every 30 seconds
   - Automatic reconnection with exponential backoff
   - Maximum 3 reconnection attempts

## MCP Integration

AppPlayer uses official MCP packages:
- `mcp_client` (v1.0.0): MCP client implementation
- `flutter_mcp_ui_runtime` (v0.2.2): Dynamic UI rendering engine

### Protocol Flow

1. **Connection**: ConnectionManager establishes transport connection
2. **Client Creation**: MCP client created with retry logic
3. **Runtime Initialization**: RuntimeManager creates UI runtime instance
4. **UI Rendering**: Runtime renders server's UI definition
5. **State Management**: Navigation and app state persisted automatically
6. **Tool Execution**: User actions executed through runtime tool executors

## Supported Platforms

- ✅ macOS
- ✅ Windows  
- ✅ Linux
- ✅ iOS
- ✅ Android

## Testing

Run tests with:
```bash
flutter test
```

Note: Some tests require mocking as they interact with external processes.

## Version

Current version: 0.1.0

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## Acknowledgments

- Built with the [Model Context Protocol](https://modelcontextprotocol.io)
- Powered by Flutter and the MCP UI Runtime
- Part of the makemind MCP ecosystem