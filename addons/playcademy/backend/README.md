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

2. **Configure Settings**: The plugin creates project settings under `playcademy/`:

    **Backend Settings** (`playcademy/backend/`):

    - `auto_start`: Auto-start servers when project opens (default: true)
    - `sandbox_port`: Port for sandbox (default: 4321)
    - `backend_port`: Port for backend (default: 8788)
    - `verbose`: Enable verbose logging (default: false)

    **Timeback Settings** (`playcademy/timeback/`):

    - `student_id`: Timeback student sourcedId (default: auto-generated mock)
    - `role`: User role - student, parent, teacher, administrator (default: student)
    - `organization_id`: Organization sourcedId (default: mock organization)
    - `organization_name`: Organization display name (default: "Playcademy Studios")
    - `organization_type`: Organization type - school, district, department, etc. (default: department)

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

The plugin uses the per-user registry at `~/.playcademy/.proc` to discover when servers are ready:

- Servers write their info when they start
- Plugin retries every 500ms for 10 seconds
- Filters by project path to find the right servers
- Uses canonical ports: 4321 (sandbox), 8788 (backend)

## Backend Server

The backend server (`playcademy dev`) is **optional** and only starts if:

- A `playcademy.config.js` or `playcademy.config.json` file exists in your project root
- The config file defines integrations (TimeBack, custom routes, etc.)

If you don't have a config file, only the sandbox will start (which is sufficient for most games).

## Timeback Integration

The plugin supports Timeback integration testing directly from Godot's project settings.

### Testing Different Roles

Change `playcademy/timeback/role` to test how your game behaves for different users:

- **student**: Default, testing the student experience
- **parent**: Test parent views and reports
- **teacher**: Test teacher views and class management
- **administrator**: Test admin-level features

### Custom Organization

Override organization settings to test school/district-specific behavior:

- Set `organization_id` to a real sourcedId for integration testing
- Set `organization_name` to customize the displayed school name
- Set `organization_type` to test different organizational contexts

Changes to Timeback settings take effect after restarting the servers (use "Reset Database" for a clean slate).

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

- Servers use canonical ports (4321 for sandbox, 8788 for backend)
- If a port is busy, the server will fail to start with a clear error
- Stop the other process using the port, or change the port in Project Settings
- Use `lsof -i :4321` (macOS/Linux) or `netstat -ano | findstr :4321` (Windows) to find what's using a port
