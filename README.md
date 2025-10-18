# PowerShell Location Shortcuts

> **Quickly jump between frequently‑used folders, create new shortcuts, and keep them in a single JSON configuration file.**

This module ships with a small collection of helper functions and an alias (`g`) that let you:

- **Navigate** to pre‑defined shortcuts (`Set-LocationShortcut`).
- **List** all available shortcuts (`Set-LocationShortcut -List`).
- **Add / Edit / Remove** shortcuts (`Add-LocationShortcut`, `Edit-LocationShortcut`, `Remove-LocationShortcut`).
- **Generate** a fresh defaults file (`New-LocationShortcuts`).
- **Read** the shortcuts hash table directly (`Get-LocationShortcuts`).

> **All data lives in a single `LocationShortcuts.json` file under your `Documents/PowerShell` directory.**

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

> **Requires PowerShell 5.1+** (works on Windows 10/11, PowerShell Core 7+)

1. **Clone or download** the repository.
2. **Import** the module or copy the script into a location in `$env:PSModulePath`.

```powershell
# Example: copy to the user's PowerShell module folder
Copy-Item -Path ".\LocationShortcuts.psm1" -Destination "$($env:PSModulePath -split ';' | Select-Object -First 1)\LocationShortcuts\LocationShortcuts.psm1"

# Then import it
Import-Module LocationShortcuts
```

> **Alternatively** you can simply run the script (`. .\LocationShortcuts.psm1`) in a PowerShell session to get the functions loaded.

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

# Re‑create the defaults file (overwrites existing config)
New-LocationShortcuts
```

---

## Functions

Below is a detailed reference for every public function in the module.

### `Set-LocationShortcut`

> Change the current directory to a named shortcut.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Location <string>` | positional 0 | Name of the shortcut to jump to. |
| `-List` | switch | Enumerates all available shortcuts. |
| `-Help` | switch | Shows help for this function. |

#### Examples of Set-LocationShortcut

```powershell
# Jump to the user's Downloads folder
Set-LocationShortcut Downloads

# List all shortcuts with validation status
Set-LocationShortcut -List

# Show help
Set-LocationShortcut -Help
```

### `Add-LocationShortcut`

> Add a new shortcut to the configuration.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Name <string>` | mandatory | Shortcut key (e.g., `Work`). |
| `-Path <string>` | mandatory | Filesystem path that the key points to. |

### Example: Adding a shortcut

```powershell
Add-LocationShortcut -Name Scripts -Path "C:\Users\john\Scripts"
```

### `Remove-LocationShortcut`

> Remove an existing shortcut.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Name <string>` | mandatory | Shortcut key to delete. |

### Example: Removing a shortcut

```powershell
Remove-LocationShortcut -Name Scripts
```

### `Edit-LocationShortcut`

> Update the path of an existing shortcut.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Name <string>` | mandatory | Shortcut key to modify. |
| `-NewPath <string>` | mandatory | New filesystem path. |

### Example: Updating a shortcut path

```powershell
Edit-LocationShortcut -Name Scripts -NewPath "D:\Tools\Scripts"
```

### `Get-LocationShortcuts`

> Retrieve the entire shortcut dictionary.

```powershell
$shortcuts = Get-LocationShortcuts
$shortcuts['Home']   # => C:\Users\john
```

#### Output Type

- `[hashtable]` mapping `string` → `string`.

### `New-LocationShortcuts`

> Create or reset the configuration file with a set of sensible defaults.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-PassThru` | switch | Return the hashtable instead of writing to console. |

### Example: Regenerating default shortcuts

```powershell
# Regenerate defaults and capture the hashtable
$defaultShortcuts = New-LocationShortcuts -PassThru
```

### `Resolve-UserFolder`

> Helper – Resolve a user folder path from the registry or fallback.

| Parameter | Type | Description |
|-----------|------|-------------|
| `-RegName <string>` | optional | Name of the `User Shell Folders` registry key. |
| `-DefaultSub <string>` | optional | Folder name to use if the registry entry is missing. |

#### User Folder Return Value

- Full path string to the resolved folder.

### `Get-LocationShortcutsConfigPath`

> Return the path to the JSON configuration file.

#### Config Path Return Value

- Full path string (e.g., `C:\Users\john\Documents\PowerShell\LocationShortcuts.json`).

---

## Configuration

### Location of the file

The file is automatically created under:

```json
{
  "Home": "C:\\Users\\john",
  "Downloads": "C:\\Users\\john\\Downloads",
  "Projects": "C:\\Users\\john\\Projects",
  "System": "C:\\Windows\\System32",
  "Programs": "C:\\Program Files",
  "Temp": "C:\\Users\\john\\AppData\\Local\\Temp"
}
```

```text
$HOME\Documents\PowerShell\LocationShortcuts.json
```

If your **Documents** folder lives elsewhere (e.g., OneDrive), the module will resolve the correct path.

### JSON schema

The file is a simple key/value map:

```json
{
  "Home": "C:\\Users\\john",
  "Downloads": "C:\\Users\\john\\Downloads",
  "Projects": "C:\\Users\\john\\Projects",
  "System": "C:\\Windows\\System32",
  "Programs": "C:\\Program Files",
  "Temp": "C:\\Users\\john\\AppData\\Local\\Temp"
}
```

- **Keys** are case‑insensitive.
- **Values** must be valid paths. The module will warn you if a path is missing.

### Adding custom shortcuts

Use `Add-LocationShortcut`, `Edit-LocationShortcut`, or edit the JSON file manually. After editing the file, call `Get-LocationShortcuts` to reload it into the current session.

### Resetting defaults

```powershell
# Overwrites the existing file
New-LocationShortcuts
```

---

## Alias

```powershell
Set-Alias -Name g -Value Set-LocationShortcut
```

The alias is exported automatically; use it for one‑letter navigation:

```powershell
g Downloads
g -List
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| `Set-LocationShortcut` says *“Unknown location”* | Typo or key not defined | Check spelling or run `g -List`. |
| `Get-LocationShortcuts` throws *“Error loading location shortcuts”* | Corrupt JSON | Delete the file, then run `New-LocationShortcuts`. |
| `Add-LocationShortcut` warns *“Path … does not exist.”* | Path is wrong or not yet created | Verify the path or create it first. |
| `Resolve-UserFolder` returns wrong folder | Registry entry missing (e.g., on clean Windows) | Uses fallback (`$env:USERPROFILE\<DefaultSub>`). |
| Alias `g` not recognized | Module not imported | Run `Import-Module LocationShortcuts`. |

---

## Contributing

Feel free to fork, tweak, and submit pull requests!  
When adding a function:

1. Add comment‑based help (`<# ... #>`).
2. Register it in the `Export-ModuleMember` list.
3. Write an example in the docs.

---

## License

© 2024 Your Name  
MIT License – see the included `LICENSE` file for details.

---
