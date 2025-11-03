# Playcademy Manifest Exporter (Godot Plugin)

A Godot editor plugin that automatically generates a `playcademy.manifest.json` file when exporting HTML5 projects, tailored for the Playcademy platform.

## Purpose

The Playcademy platform requires a `playcademy.manifest.json` file to correctly integrate and load HTML5 games. This plugin automates the creation of this manifest, ensuring your Godot web exports are Playcademy-ready.

## Features

- **Automatic Manifest Generation:** Creates the `playcademy.manifest.json` file in your web export directory with build metadata (Godot version, timestamp).
- **Auto-Zipping:** Automatically packages your entire export into a ZIP file ready for upload to the Playcademy platform.
- **Smart Export Handling:** Intelligently detects export paths and skips auto-zipping for non-empty directories to prevent file conflicts.
- **Playcademy Ready:** Simplifies the preparation of your Godot web games for the Playcademy platform.
- **Seamless Integration:** Works automatically during the standard Godot HTML5 export process once the plugin is enabled.

## Manual Installation

1.  Download the contents of this addon (the `manifest_export` folder).
2.  Place the `manifest_export` folder into your Godot project's `addons/` directory. If you don't have an `addons/` directory, create one at the root of your project.
    Your project structure should look like:
    ```
    my_godot_project/
    ├── addons/
    │   └── playcademy/manifest_exporter/
    │       ├── plugin.gd
    │       ├── plugin.cfg
    │       ├── playcademy_exporter.gd
    └── project.godot
    ... (other project files)
    ```
3.  Enable the plugin:
    - Open your Godot project.
    - Go to `Project` -> `Project Settings...` -> `Plugins` tab.
    - Find "Playcademy Manifest Exporter" in the list and check the "Enable" box.

## How to Use

Once installed and enabled, the plugin works automatically. When you export your project for the "Web" (HTML5) platform:

1. **Manifest Generation**: The `playcademy.manifest.json` file is created in your export directory with build metadata
2. **Auto-Zipping**: A ZIP file is automatically created containing your entire export, ready for upload to the Playcademy platform
3. **Clean Output**: The original export directory is preserved, and the ZIP file is placed in the parent directory

The plugin intelligently handles export paths and will skip auto-zipping if it detects a non-empty export directory to prevent overwriting existing files.

## License

This plugin is released under the MIT License. See the [LICENSE](LICENSE) file for more details.
