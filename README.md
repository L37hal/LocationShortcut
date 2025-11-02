# PowerShell Location Shortcuts

> **Quickly jump between frequently‑used folders, create new shortcuts, and keep them in a single JSON configuration file.**

This module ships with a collection of helper functions and an alias (`g`) that let you:

- **Navigate** to pre‑defined shortcuts (`Set-LocationShortcut`).
- **List** all available shortcuts (`Set-LocationShortcut -List`).
- **Add / Edit / Remove** shortcuts (`Add-LocationShortcut`, `Edit-LocationShortcut`, `Remove-LocationShortcut`).
- **Generate** a fresh defaults file (`New-LocationShortcuts`).
- **Read** the shortcuts hash table directly (`Get-LocationShortcuts`).

> **All data lives in a single `LocationShortcuts.json` file under your `Documents\PowerShell` directory.**

---

## Table of Contents

| Section | Description |
|---------|-------------|
| [Installation](#installation) | How to add the module to your environment |
| [Quick Start](#quick-start) | One‑liner usage |
| [Functions](#functions) | Detailed docs for every public function |
| [Configuration](#configuration) | JSON schema, default values, customizing |
| [Alias](#alias) | The short `g` command |
| [Troubleshooting](#troubleshooting) | Common pitfalls and fixes |
| [Contributing](#contributing) | How to improve the module |
| [License](#license) | Copyright and license |

---

## Installation

> **Requires PowerShell 5.1+** (works on Windows PowerShell 5.1, PowerShell Core 7+)

### Option 1: Manual Installation

1. **Clone or download** the repository.
2. **Copy** both `LocationShortcuts.psm1` and `LocationShortcuts.psd1` to your PowerShell modules directory:

```powershell
# Copy to user's PowerShell module folder
$modulePath = Join-Path ($env:PSModulePath -split ';' | Where-Object { $_ -like "*$env:USERPROFILE*" } | Select-Object -First 1) "LocationShortcuts"
New-Item -ItemType Directory -Path $modulePath -Force
Copy-Item -Path ".\LocationShortcuts.psm1" -Destination $modulePath
Copy-Item -Path ".\LocationShortcuts.psd1" -Destination $modulePath

# Import the module
Import-Module LocationShortcuts
```

### Option 2: Manual Load (Testing)

```powershell
# Load directly from the script file (for testing)
Import-Module .\LocationShortcuts.psm1
```

### Option 3: Auto-load on Startup

Add this line to your PowerShell profile (`$PROFILE`):

```powershell
Import-Module LocationShortcuts
```

---

## Quick Start

```powershell
# After importing the module

# Jump to a pre‑defined shortcut
g Home          # (same as Set-LocationShortcut Home)

# List all available shortcuts
g -List

# Add a new shortcut
Add-LocationShortcut -Name WorkDocs -Path "C:\Users\john\Documents\Work"

# Edit an existing shortcut
Edit-LocationShortcut -Name WorkDocs -NewPath "D:\Docs\Work"

# Remove a shortcut
Remove-LocationShortcut -Name WorkDocs

# Re‑create the defaults file (overwrites existing config with confirmation)
New-LocationShortcuts
```

---

## Functions

Below is a detailed reference for every public function in the module.

### `Set-LocationShortcut`

> Change the current directory to a named shortcut.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Location <string>` | positional 0 | Name of the shortcut to jump to. Supports tab-completion. |
| `-List` | switch | Enumerates all available shortcuts in a formatted table. |
| `-Help` | switch | Shows detailed help for this function. |

#### Examples

```powershell
# Jump to the user's Downloads folder
Set-LocationShortcut Downloads

# Or use the alias
g Downloads

# List all shortcuts with their paths
g -List

# Show help
g -Help
```

---

### `Add-LocationShortcut`

> Add a new shortcut to the configuration.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Name <string>` | mandatory | Shortcut key (e.g., `Work`). Must be unique and contain only letters, numbers, hyphens, and underscores. |
| `-Path <string>` | mandatory | Filesystem path that the key points to. Can be relative or absolute. |

**Note:** Supports `-WhatIf` and `-Confirm` parameters.

#### Example

```powershell
Add-LocationShortcut -Name Scripts -Path "C:\Users\john\Scripts"

# Using relative paths (will be resolved to absolute)
Add-LocationShortcut -Name WebDev -Path ".\WebProjects"

# Preview the action without executing
Add-LocationShortcut -Name Test -Path "C:\Test" -WhatIf
```

---

### `Remove-LocationShortcut`

> Remove an existing shortcut.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Name <string>` | mandatory | Shortcut key to delete. Supports tab-completion. |

**Note:** Supports `-WhatIf` and `-Confirm` parameters for safe deletion.

#### Example

```powershell
Remove-LocationShortcut -Name Scripts

# Preview before removing
Remove-LocationShortcut -Name Scripts -WhatIf

# Skip confirmation prompt
Remove-LocationShortcut -Name Scripts -Confirm:$false
```

---

### `Edit-LocationShortcut`

> Update the path of an existing shortcut.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Name <string>` | mandatory | Shortcut key to modify. Supports tab-completion. |
| `-NewPath <string>` | mandatory | New filesystem path. Can be relative or absolute. |

**Note:** Supports `-WhatIf` and `-Confirm` parameters.

#### Example

```powershell
Edit-LocationShortcut -Name Scripts -NewPath "D:\Tools\Scripts"

# Using relative paths
Edit-LocationShortcut -Name Projects -NewPath ".\MyProjects"

# Preview the change
Edit-LocationShortcut -Name Scripts -NewPath "D:\Tools" -WhatIf
```

---

### `Get-LocationShortcuts`

> Retrieve the entire shortcut dictionary.

Returns a hashtable of all configured shortcuts. If the configuration file doesn't exist, it creates one with defaults.

#### Example

```powershell
# Get all shortcuts
$shortcuts = Get-LocationShortcuts

# Access specific shortcut
$shortcuts['Home']   # => C:\Users\john

# Display all shortcuts
$shortcuts | Format-Table
```

#### Output Type

- `[hashtable]` mapping `string` → `string`.

---

### `New-LocationShortcuts`

> Create or reset the configuration file with a set of default shortcuts.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-PassThru` | switch | Return the hashtable instead of writing to console. |

**Note:** Supports `-WhatIf` and `-Confirm` parameters. Will prompt before overwriting existing configuration.

#### Default Shortcuts Created

- **User Folders:** Home, Downloads, Documents, Pictures, Music, Videos, Scripts, Projects
- **System:** System (System32), Programs (Program Files), Programs32, ProgramData, Root (C:\)
- **Development:** Steam, Temp, CTemp (C:\Temp)

#### Example

```powershell
# Create/reset defaults (will prompt for confirmation if file exists)
New-LocationShortcuts

# Regenerate defaults and capture the hashtable
$defaultShortcuts = New-LocationShortcuts -PassThru

# Preview what would be created
New-LocationShortcuts -WhatIf

# Force recreation without confirmation
New-LocationShortcuts -Confirm:$false
```

---

## Configuration

### Location of the File

The configuration file is automatically created at:

```text
$HOME\Documents\PowerShell\LocationShortcuts.json
```

If your **Documents** folder is redirected (e.g., to OneDrive), the module automatically detects the correct location by querying the Windows registry.

### JSON Schema

The file is a simple key/value map:

```json
{
  "Home": "C:\\Users\\john",
  "Downloads": "C:\\Users\\john\\Downloads",
  "Documents": "C:\\Users\\john\\Documents",
  "Projects": "C:\\Users\\john\\Projects",
  "Scripts": "C:\\Users\\john\\Scripts",
  "System": "C:\\Windows\\System32",
  "Programs": "C:\\Program Files",
  "Programs32": "C:\\Program Files (x86)",
  "ProgramData": "C:\\ProgramData",
  "Steam": "C:\\Program Files (x86)\\Steam\\steamapps\\common",
  "Temp": "C:\\Users\\john\\AppData\\Local\\Temp",
  "CTemp": "C:\\Temp",
  "Root": "C:\\"
}
```

- **Keys** are case‑insensitive (though stored with their original casing).
- **Values** must be valid paths. The module validates paths before adding shortcuts.
- Only paths that exist on your system are included in the default configuration.

### Adding Custom Shortcuts

#### Via Commands

```powershell
# Recommended: Use the provided functions
Add-LocationShortcut -Name MyProject -Path "D:\Projects\MyApp"
```

#### Via Manual Editing

You can also edit the JSON file directly:

1. Open `$HOME\Documents\PowerShell\LocationShortcuts.json` in a text editor
2. Add your shortcuts in the JSON format
3. Save the file
4. The changes take effect immediately (no need to reload)

### Resetting to Defaults

```powershell
# Overwrites the existing file (prompts for confirmation)
New-LocationShortcuts

# Force overwrite without confirmation
New-LocationShortcuts -Confirm:$false
```

---

## Alias

The module automatically exports a convenient alias:

```powershell
Set-Alias -Name g -Value Set-LocationShortcut
```

Use it for quick, one‑letter navigation:

```powershell
g Downloads    # Jump to Downloads
g -List        # List all shortcuts
g -Help        # Show help
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `Set-LocationShortcut` says *"Unknown location"* | Typo or key not defined | Check spelling or run `g -List` to see available shortcuts. |
| `Get-LocationShortcuts` throws *"Error loading location shortcuts"* | Corrupt or invalid JSON | Delete the file at `$HOME\Documents\PowerShell\LocationShortcuts.json`, then run `New-LocationShortcuts`. |
| `Add-LocationShortcut` warns *"Path does not exist"* | Path is incorrect or not yet created | Verify the path exists. Use `Test-Path` to check, or create the directory first with `New-Item -ItemType Directory`. |
| `Add-LocationShortcut` warns *"Shortcut already exists"* | Attempting to add a duplicate | Use `Edit-LocationShortcut` to modify existing shortcuts, or `Remove-LocationShortcut` first. |
| Tab-completion not working for shortcut names | Module not properly loaded | Ensure module is imported: `Import-Module LocationShortcuts -Force` |
| Alias `g` not recognized | Module not imported or alias conflict | Run `Import-Module LocationShortcuts`. Check for conflicts with `Get-Alias g`. |
| Configuration file not found | First run or file was deleted | Run `New-LocationShortcuts` to create default configuration. |
| OneDrive folders not detected | Registry keys not set | The module uses fallback paths under `$env:USERPROFILE`. Works for most scenarios. |

### Getting Verbose Output

For troubleshooting, use the `-Verbose` parameter:

```powershell
Set-LocationShortcut Downloads -Verbose
Add-LocationShortcut -Name Test -Path "C:\Test" -Verbose
```

---

## Features

### ✅ Implemented Features

- **Quick Navigation:** Jump to any configured directory with minimal typing
- **Tab-Completion:** All shortcut names support tab-completion
- **Case-Insensitive:** Shortcut names work regardless of case
- **OneDrive Support:** Automatically detects OneDrive-redirected folders
- **Path Validation:** Validates paths before creating/editing shortcuts
- **Safe Operations:** `-WhatIf` and `-Confirm` support for destructive operations
- **Relative Paths:** Automatically resolves relative paths to absolute
- **Error Handling:** Comprehensive error messages with actionable suggestions
- **Cross-Platform:** Works on Windows PowerShell 5.1 and PowerShell Core 7+
- **Default Shortcuts:** Sensible defaults for common Windows locations

---

## Contributing

Contributions are welcome! To contribute:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Make** your changes following PowerShell best practices:
   - Add comment-based help to all functions
   - Include parameter validation
   - Add examples to help documentation
   - Update the README if adding new features
4. **Test** your changes thoroughly
5. **Register** new functions in the `Export-ModuleMember` list
6. **Commit** your changes (`git commit -m 'Add amazing feature'`)
7. **Push** to the branch (`git push origin feature/amazing-feature`)
8. **Open** a Pull Request

### Code Standards

- Follow PowerShell approved verbs (`Get-`, `Set-`, `Add-`, `Remove-`, `Edit-`, `New-`)
- Use proper parameter validation attributes
- Include comprehensive comment-based help
- Add verbose output for troubleshooting
- Handle errors gracefully
- Support `ShouldProcess` for functions that modify data

---

## License

© 2025 PowerShell Module Author  
MIT License – see the included `LICENSE` file for details.

---

## Changelog

### Version 1.0.0 (2025-11-02)

**Initial Release**

- Core navigation functionality with `Set-LocationShortcut`
- CRUD operations for shortcuts (Add, Edit, Remove)
- Default configuration generation
- OneDrive folder detection
- Tab-completion support
- `ShouldProcess` implementation for safe operations
- Comprehensive error handling and validation
- Cross-platform compatibility (Windows PowerShell 5.1+ and PowerShell Core 7+)

---

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section
2. Run commands with `-Verbose` to see detailed output
3. Verify your PowerShell version: `$PSVersionTable.PSVersion`
4. Check if the module is loaded: `Get-Module LocationShortcuts`
5. Open an issue on the repository with details

---

**Happy navigating! 🚀**
