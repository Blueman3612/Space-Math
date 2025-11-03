# Playcademy Godot Bundle

This directory contains Playcademy assets for Godot Engine, designed to streamline the integration of your Godot games with the Playcademy platform.

The asset bundle includes the following key components:

## 1. Manifest Exporter Plugin (`manifest_exporter/`)

This is a Godot editor plugin that helps you prepare your game for the Playcademy platform. Its primary functions include:

- **Automatic Manifest Generation**: Creates the required `playcademy.manifest.json` file with build metadata (Godot version, build timestamp)
- **Auto-Zipping**: Automatically packages your entire export into a ZIP file ready for upload to the Playcademy platform
- **Smart Export Handling**: Intelligently detects export paths and skips auto-zipping for non-empty directories to prevent file conflicts
- **Asset Packaging**: Assists in organizing and declaring the assets your game uses, ensuring they are correctly recognized and handled by the Playcademy system
- **Simplified Export**: Streamlines the process of exporting your game in a format compatible with Playcademy

To use the Manifest Exporter, simply enable it in your Godot project's `Project > Project Settings > Plugins` tab after downloading this asset via AssetLib (or else manually placing this directory into your project's `addons/` directory).

## 2. Playcademy SDK & Web Shell

This section covers the Playcademy Software Development Kit (SDK) and the HTML shell required for web-based deployments.

### Playcademy SDK (`sdk/`)

The SDK provides the necessary tools and libraries to connect your Godot game with Playcademy's backend services. This enables features such as:

- User authentication and management.
- Player inventory interactions.
- Runtime behaviour (e.g. exit game)

Refer to the [SDK documentation](https://docs.playcademy.net/platform-guides/godot.html) for details on how to integrate these features into your game logic.

### Required HTML Shell (`shell.html`) for Web Exports

When deploying your game to the Playcademy web platform, the SDK relies critically on the provided `shell.html`. This HTML file is not just a template but a **vital component** specifically configured to:

- Ensure seamless operation and proper initialization of your game within the Playcademy web environment.
- Handle the embedding of the Godot game canvas correctly.
- Facilitate essential communication channels between your Godot game, the SDK, and the Playcademy platform.

**Using a custom HTML shell without incorporating the necessary Playcademy hooks may lead to SDK features not functioning as expected, or a complete failure of integration on the web platform.**

## 3. Development Sandbox Plugin (`sandbox/`)

The Development Sandbox plugin provides a local development environment that enables full Playcademy SDK functionality during game development. Key features include:

- **Local SDK Support**: Test user authentication, inventory management, and other platform features without deploying
- **Automatic Server Management**: Starts and stops the sandbox server automatically when you open/close your project
- **Editor Integration**: Provides a dock panel with sandbox status and controls
- **Quick Iteration**: Run your game locally (Cmd+B/F5) with full platform functionality

The sandbox requires Node.js/npm or Bun to be installed and the `@playcademy/sandbox` package installed globally.

## 4. Installation

1.  Download and copy (manually or via AssetLib) the entire `playcademy` directory into the `addons/` folder of your Godot project.
2.  Enable both plugins via `Project > Project Settings > Plugins` in the Godot editor:
    - **"Playcademy Manifest Exporter"** plugin
    - **"Playcademy Sandbox"** plugin (for local development)
3.  Setup AutoLoad for SDK: Add `res://addons/playcademy/sdk/PlaycademySDK.gd` as an AutoLoad singleton:
    - Go to `Project > Project Settings > AutoLoad`
    - Click "Add" and select `res://addons/playcademy/sdk/PlaycademySDK.gd` for the "Path"
    - Set "Name" to `PlaycademySdk`
    - Ensure "Enable" is checked
4.  Configure web export settings to utilize the provided `shell.html` if deploying to the Playcademy platform:
    - Go to `Project > Export`
    - Select the `Web (Runnable)` preset
    - Under `Custom HTML Shell`, specify `res://addons/playcademy/shell.html`
