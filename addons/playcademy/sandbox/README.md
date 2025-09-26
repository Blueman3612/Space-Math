# Playcademy Development Sandbox Plugin

This Godot editor plugin automatically manages a local development sandbox server for testing Playcademy SDK integration during game development.

## Features

- **Automatic Sandbox Management**: Starts and stops the sandbox server automatically
- **Editor Integration**: Provides a dock panel with sandbox status and controls
- **Project Settings Integration**: Configurable through Godot's project settings
- **Local SDK Support**: Enables the Playcademy SDK to work in local development mode

## How It Works

When enabled, this plugin:

1. **Auto-starts** the `@playcademy/sandbox` server when you open your project (if enabled)
2. **Monitors** the sandbox server status and provides visual feedback
3. **Integrates** with the Playcademy SDK to enable local development mode
4. **Manages** the server lifecycle (start/stop/restart) through the editor UI

## Setup

### Prerequisites

- **Node.js/npm** or **Bun**:
    - npm: Install Node.js from https://nodejs.org
    - bun: `curl -fsSL https://bun.sh/install | bash`
- **Sandbox Package**: Install the sandbox globally:
    - npm: `npm install -g @playcademy/sandbox`
    - bun: `bun add -g @playcademy/sandbox`

### Installation

1. **Enable the Plugin**: Go to `Project > Project Settings > Plugins` and enable "Playcademy Development Sandbox"

2. **Configure Settings**: The plugin will automatically create project settings under `playcademy/sandbox/`:

    - `auto_start`: Whether to automatically start the sandbox when the project opens (default: true)
    - `port`: Port for the sandbox server (default: 4321)
    - `verbose`: Enable verbose logging (default: false)

3. **Verify Setup**: Look for the "Playcademy Sandbox" dock panel in the editor (usually in the left dock area)

## Usage

### Automatic Mode

With `auto_start` enabled (default), the sandbox will automatically start when you:

- Open the project in Godot
- Run the project (Cmd+B / F5)

### Manual Mode

Use the dock panel controls to:

- **Start Sandbox**: Manually start the sandbox server
- **Stop Sandbox**: Stop the running sandbox server
- **Restart Sandbox**: Restart the sandbox server
- **Toggle Auto-start**: Enable/disable automatic startup

### Status Indicators

The dock panel shows:

- **Status**: Current sandbox state (Stopped, Starting, Running, Error)
- **URL**: The sandbox API endpoint (when running)
- **Controls**: Buttons to manage the sandbox lifecycle

## Local Development Workflow

With this plugin enabled, your Godot development workflow becomes:

1. **Open Project**: Sandbox starts automatically
2. **Run Project** (Cmd+B): Game runs with full Playcademy SDK functionality
3. **Test SDK Features**: User authentication, inventory, etc. work locally
4. **Iterate Quickly**: No need to export and upload to test platform features

## Troubleshooting

### "Neither npm nor bun found" Error

- Install Node.js (includes npm): https://nodejs.org
- Or install Bun: `curl -fsSL https://bun.sh/install | bash`
- Ensure the runtime is in your PATH
- Restart Godot after installing

### "Failed to start sandbox" Error

- Install the sandbox package globally:
    - npm: `npm install -g @playcademy/sandbox`
    - bun: `bun add -g @playcademy/sandbox`
- Ensure your JavaScript runtime is properly installed
- Try restarting Godot after installing dependencies

### Sandbox Health Check Failed

- Check if another process is using the configured port
- Try changing the port in project settings
- Ensure the sandbox package is properly installed

### SDK Not Working in Local Mode

- Verify the sandbox is running (green status in dock)
- Check the Godot console for SDK initialization messages
- Ensure your game code properly handles the `sdk_ready` signal

## Technical Details

### How Local SDK Mode Works

When running in the Godot editor (not a web build), the Playcademy SDK:

1. **Detects** it's not in a web environment
2. **Attempts** to connect to the local sandbox server
3. **Initializes** a mock client that uses HTTP requests instead of JavaScript bridge
4. **Provides** the same API surface as the web version

### Sandbox Server Features

The local sandbox provides:

- **Mock user authentication**
- **Local inventory management**
- **Currency systems**
- **Game state persistence**
- **All Playcademy API endpoints**

This allows you to develop and test your game's Playcademy integration without needing to deploy to the platform.

## Configuration

### Project Settings

All settings are stored in `project.godot` under the `[playcademy]` section:

```ini
[playcademy]

sandbox/auto_start=true
sandbox/port=4321
sandbox/verbose=false
```

### Advanced Configuration

For advanced users, you can also configure:

- Custom sandbox package paths
- Additional CLI arguments
- Network timeouts

These settings may be added to project settings as needed.
