<!--
Guidance for AI contributors (Copilot / code agents) working on the LocationShortcuts PowerShell module.
Keep this file short and concrete: reference real files and idiomatic patterns used in the repository.
-->

# Copilot instructions — LocationShortcuts PowerShell module

Purpose: Help a coding AI make safe, consistent edits to the `LocationShortcuts` PowerShell module. Focus on small, testable changes: bug fixes, small features, docs, and exports.

Key files
- `LocationShortcuts.psm1` — implementation of all functions and the single exported alias (`g`). Primary source for behaviour.
- `LocationShortcuts.psd1` — module manifest (registers metadata); update only when adding new files, changing version or dependencies.
- `README.md` — user-facing docs. Keep examples in sync with function signatures in `LocationShortcuts.psm1`.

Big picture
- This is a single-file PowerShell module that manages a JSON-backed map of named folder shortcuts stored at `%USERPROFILE%\Documents\PowerShell\LocationShortcuts.json` (location resolved via `Get-LocationShortcutsConfigPath`).
- Public API: Set-LocationShortcut (alias `g`), Add-LocationShortcut, Edit-LocationShortcut, Remove-LocationShortcut, Get-LocationShortcuts, New-LocationShortcuts.
- Data flow: functions call `Get-LocationShortcutsConfigPath` → read/write JSON file → return or mutate an in-memory hashtable produced by `Get-LocationShortcuts`.

Conventions & patterns
- Comment-based help is used for all public functions; preserve and update `.SYNOPSIS`, `.PARAMETER`, and `.EXAMPLE` blocks when changing signatures.
- IO uses `Test-Path`, `Get-Content -Raw`, `ConvertFrom-Json -AsHashtable`, `ConvertTo-Json`, and `Set-Content`. Keep `-ErrorAction` usage as in-file for consistent error handling.
- Warnings use `Write-Warning`; fatal errors generally use `Write-Error`. When returning data, use typed outputs (e.g., `[hashtable]` for `Get-LocationShortcuts`).
- Export list is explicitly declared via `Export-ModuleMember`; if you add a public function, ensure it’s included there and documented in `README.md`.

Testing & manual validation
- No automated tests present. Use a PowerShell interactive session to validate changes quickly.
  - Example: dot-source the module during development: `. .\LocationShortcuts.psm1` then call functions (e.g., `g -List`, `New-LocationShortcuts -PassThru`).
- When changing config-path logic, test on machines with and without OneDrive by verifying `Get-LocationShortcutsConfigPath` output and that `New-LocationShortcuts` creates the directory.

Common pitfalls (from code inspection)
- JSON round-trip: `.ConvertTo-Json` on a hashtable yields an object — ensure consumers expect hashtable via `ConvertFrom-Json -AsHashtable` when reading.
- Registry read: `Resolve-UserFolder` reads `HKCU` keys and expands environment variables. Validate on systems where keys are missing or point to OneDrive paths.
- Exports: alias `g` is created via `Set-Alias` and exported; avoid re-binding `g` to other commands.

Safe edit checklist for AIs
1. Update comment-based help when changing a function signature or behaviour.
2. Run a quick manual validation by dot-sourcing `LocationShortcuts.psm1` in PowerShell and exercising the changed function(s).
3. If the change writes config files, ensure the path returned by `Get-LocationShortcutsConfigPath` is used and the target directory is created with `New-Item -Force` as existing code does.
4. Add new public functions to `Export-ModuleMember` and update `README.md` examples.
5. Prefer small, localized changes. If a larger refactor is required, leave a clear PR description and update `README.md` and module manifest.

Examples (copyable snippets agents can use when editing)
- Dot-source during dev:
  . .\LocationShortcuts.psm1

- Regenerate defaults and return the hashtable for assertions:
  $h = New-LocationShortcuts -PassThru

- Read the config path for debugging:
  Get-LocationShortcutsConfigPath

Files to mention in PR descriptions
- `LocationShortcuts.psm1` — code changes
- `README.md` — update examples/help
- `LocationShortcuts.json` (generated) — only include in PR when adding example config; otherwise ignore

When unsure
- If behavior depends on a real Windows environment (registry, OneDrive paths), describe the change and request the human maintainer to validate on their machine rather than making risky assumptions.

Ask the maintainer after making edits: "Which Windows profiles (OneDrive vs classic Documents) should I test against?" This helps validate `Get-LocationShortcutsConfigPath` and `Resolve-UserFolder` edge-cases.

End of instructions.
