# Playcademy Backend Plugin

This Godot editor plugin automatically manages Playcademy development servers for local game development.

## Features

- **Automatic Server Management**: Starts and stops dev servers automatically
- **Dual Server Support**: Manages both sandbox (required) and backend (optional)
- **Editor Integration**: Provides a bottom panel tab with server status and controls
- **Project Settings Integration**: Configurable through Godot's project settings
- **Smart Detection**: Only starts backend if `playcademy.config.js/json` exists
- **Registry-Based Discovery**: Uses `~/.playcademy/.proc` to discover actual server ports

## How It Works

When enabled, this plugin:

1. **Auto-starts** the `@playcademy/sandbox` server when you open your project
2. **Auto-starts** the backend (`playcademy dev`) if a config file exists
3. **Monitors** server status through the per-user registry
4. **Provides** visual feedback via bottom panel tab
5. **Manages** server lifecycle (start/stop/restart) through the editor UI

## Setup

### Prerequisites

- **Node.js/npm** or **Bun**:
    - npm: Install Node.js from https://nodejs.org
    - bun: `curl -fsSL https://bun.sh/install | bash`
- **Sandbox Package**: `npm install -g @playcademy/sandbox` or `bun add -g @playcademy/sandbox`
- **CLI Package** (for backend): `npm install -g playcademy` or `bun add -g playcademy`

### Installation

1. **Enable the Plugin**: Go to `Project > Project Settings > Plugins` and enable "Playcademy Backend"

2. **Configure Settings**: The plugin creates project settings under `playcademy/backend/`:

    - `auto_start`: Auto-start servers when project opens (default: true)
    - `sandbox_port`: Preferred port for sandbox (default: 4321)
    - `backend_port`: Preferred port for backend (default: 8788)
    - `verbose`: Enable verbose logging (default: false)

3. **Verify Setup**: Look for the "Playcademy" tab in the bottom panel (with Inspector/Node/History)

## Usage

### Automatic Mode

With `auto_start` enabled (default), servers will automatically start when you:

- Open the project in Godot
- Run the project (Cmd+B / F5)

### Manual Mode

Use the bottom panel controls to:

- **Start Servers**: Manually start both sandbox and backend (if config exists)
- **Stop Servers**: Stop all running servers
- **Restart Servers**: Restart all servers

## Server Discovery

The plugin uses the per-user registry at `~/.playcademy/.proc` to discover actual server ports:

- Servers write their info when they start
- Plugin retries every 500ms for 5 seconds
- Filters by project path to find the right servers
- Handles port conflicts gracefully (servers find next available port)

## Backend Server

The backend server (`playcademy dev`) is **optional** and only starts if:

- A `playcademy.config.js` or `playcademy.config.json` file exists in your project root
- The config file defines integrations (TimeBack, custom routes, etc.)

If you don't have a config file, only the sandbox will start (which is sufficient for most games).

## Troubleshooting

### Servers won't start

- Verify Node.js/Bun is installed: `node --version` or `bun --version`
- Install packages globally: `npm install -g @playcademy/sandbox playcademy`
- Check console output for error messages

### Can't find servers in registry

- Make sure servers actually started (check terminal)
- Verify `~/.playcademy/.proc` file exists
- Check that `projectRoot` in registry matches your Godot project path

### Port conflicts

- Servers automatically find next available port if preferred port is busy
- Check the panel to see actual URLs being used
- You can change preferred ports in Project Settings
