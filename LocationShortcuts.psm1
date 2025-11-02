#Requires -Version 5.1

<#
.SYNOPSIS
    LocationShortcuts - A PowerShell module for managing directory navigation shortcuts.

.DESCRIPTION
    This module provides functionality to create, manage, and navigate to frequently used
    directories using customizable shortcuts stored in a JSON configuration file.
    
    The configuration file is stored in Documents\PowerShell\LocationShortcuts.json and
    automatically handles OneDrive redirection.

.NOTES
    File Name      : LocationShortcuts.psm1
    Author         : Leigh Butterworth
    Prerequisite   : PowerShell 5.1 or later
    
.LINK
    https://docs.microsoft.com/powershell/
#>

#region Private Functions

function Get-LocationShortcutsConfigPath {
    <#
    .SYNOPSIS
        Gets the path to the LocationShortcuts.json configuration file.
    
    .DESCRIPTION
        Determines the correct path for the configuration file, properly handling OneDrive 
        redirection by querying the Windows registry. Ensures the containing directory exists
        before returning the path.
    
    .OUTPUTS
        System.String. The full path to LocationShortcuts.json.
    
    .EXAMPLE
        $configPath = Get-LocationShortcutsConfigPath
        Gets the full path where the configuration file is stored.
    
    .NOTES
        This function is marked as private and not exported from the module.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Default fallback location
    $defaultDocuments = Join-Path -Path $env:USERPROFILE -ChildPath 'Documents'
    $docPath = $null

    # Attempt to read the actual Documents folder location from registry
    # This handles OneDrive redirection and custom folder locations
    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    
    if (Test-Path -Path $regPath) {
        try {
            $reg = Get-ItemProperty -Path $regPath -Name 'Personal' -ErrorAction SilentlyContinue
            if ($reg -and $reg.Personal) {
                # Expand environment variables in the registry value
                $expanded = [Environment]::ExpandEnvironmentVariables($reg.Personal)
                
                # Validate the path is rooted and exists
                if ([IO.Path]::IsPathRooted($expanded) -and (Test-Path -Path $expanded)) {
                    $docPath = $expanded
                }
            }
        }
        catch {
            Write-Verbose "Could not read registry path: $_"
        }
    }

    # Determine base path: prefer OneDrive location if detected, otherwise use default
    if ($docPath -and ($docPath -match '\\OneDrive(\\| - |$)')) {
        $documentsBase = $docPath
    }
    else {
        $documentsBase = $defaultDocuments
    }

    # Construct the full config file path
    $configPath = Join-Path -Path $documentsBase -ChildPath 'PowerShell\LocationShortcuts.json'

    # Ensure the parent directory exists
    $configDir = Split-Path -Path $configPath -Parent
    if (-not (Test-Path -Path $configDir)) {
        try {
            New-Item -ItemType Directory -Path $configDir -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created configuration directory: $configDir"
        }
        catch {
            Write-Error "Failed to create configuration directory '$configDir': $_"
        }
    }

    return $configPath
}

function Resolve-UserFolder {
    <#
    .SYNOPSIS
        Resolves a user folder path from the Windows registry or uses a fallback.
    
    .DESCRIPTION
        Attempts to retrieve the correct path for user special folders (Documents, Downloads, 
        Pictures, etc.) by querying the Windows registry. Falls back to standard locations 
        under %USERPROFILE% if registry lookup fails.
    
    .PARAMETER RegName
        The registry value name in 'User Shell Folders' to look up. Can be $null for folders
        without registry entries (e.g., Downloads, Scripts).
    
    .PARAMETER DefaultSub
        The default subfolder name under %USERPROFILE% to use as a fallback location.
    
    .OUTPUTS
        System.String. The resolved filesystem path.
    
    .EXAMPLE
        Resolve-UserFolder -RegName 'Personal' -DefaultSub 'Documents'
        Resolves the user's Documents folder path, checking registry first.
    
    .EXAMPLE
        Resolve-UserFolder -RegName $null -DefaultSub 'Downloads'
        Resolves the Downloads folder using only the fallback path.
    
    .NOTES
        This function is marked as private and not exported from the module.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [string]$RegName,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DefaultSub
    )

    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $resolvedPath = $null

    # Only attempt registry lookup if RegName is provided
    if (-not [string]::IsNullOrWhiteSpace($RegName) -and (Test-Path -Path $regPath)) {
        try {
            $reg = Get-ItemProperty -Path $regPath -Name $RegName -ErrorAction SilentlyContinue
            if ($reg -and $reg.$RegName) {
                # Expand any environment variables in the registry value
                $expanded = [Environment]::ExpandEnvironmentVariables($reg.$RegName)
                
                # Validate the path is properly rooted and exists
                if ([IO.Path]::IsPathRooted($expanded) -and (Test-Path -Path $expanded)) {
                    $resolvedPath = $expanded
                    Write-Verbose "Resolved '$DefaultSub' from registry: $resolvedPath"
                }
            }
        }
        catch {
            Write-Verbose "Error reading registry for '$RegName': $_"
        }
    }

    # Use fallback path if registry lookup failed or wasn't attempted
    if (-not $resolvedPath) {
        $resolvedPath = Join-Path -Path $env:USERPROFILE -ChildPath $DefaultSub
        Write-Verbose "Using fallback path for '$DefaultSub': $resolvedPath"
    }

    return $resolvedPath
}

#endregion Private Functions

#region Public Functions

function Get-LocationShortcuts {
    <#
    .SYNOPSIS
        Retrieves all configured location shortcuts.
    
    .DESCRIPTION
        Reads the LocationShortcuts.json configuration file and returns the shortcuts as a 
        hashtable. If the configuration file doesn't exist, creates a new one with default 
        shortcuts for common Windows locations.
    
    .OUTPUTS
        System.Collections.Hashtable. A mapping of shortcut names to their filesystem paths.
    
    .EXAMPLE
        $shortcuts = Get-LocationShortcuts
        Retrieves all configured shortcuts as a hashtable.
    
    .EXAMPLE
        Get-LocationShortcuts | Format-Table
        Displays all shortcuts in a formatted table.
    
    .NOTES
        This function is the foundation for all other shortcut operations.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    try {
        # Get the path to the configuration file
        $configPath = Get-LocationShortcutsConfigPath
        Write-Verbose "Configuration path: $configPath"
        
        # If configuration file exists, load and parse it
        if (Test-Path -Path $configPath) {
            Write-Verbose "Loading existing configuration from: $configPath"
            $json = Get-Content -Path $configPath -Raw -ErrorAction Stop
            
            # Parse JSON and convert to hashtable for easier manipulation
            $shortcuts = $json | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            Write-Verbose "Successfully loaded $($shortcuts.Count) shortcuts"
            return $shortcuts
        }
        
        # If no configuration exists, create a new one with defaults
        Write-Verbose "Configuration file not found. Creating new default configuration."
        return New-LocationShortcuts -PassThru
    }
    catch {
        Write-Error "Error loading location shortcuts from '$configPath': $_"
        # Return empty hashtable as safe fallback
        return @{}
    }
}

function New-LocationShortcuts {
    <#
    .SYNOPSIS
        Creates or resets the location shortcuts configuration file with defaults.
    
    .DESCRIPTION
        Generates a new configuration file with default shortcuts for common Windows locations,
        user folders, and development directories. Any existing configuration will be overwritten.
        
        Default shortcuts include:
        - User folders: Home, Documents, Downloads, Pictures, Music, Videos
        - Development: Projects, Scripts
        - System: System32, ProgramFiles, ProgramData, Temp
        - Common apps: Steam library
    
    .PARAMETER PassThru
        When specified, returns the generated shortcuts hashtable without displaying output.
    
    .OUTPUTS
        When -PassThru is specified: System.Collections.Hashtable
    
    .EXAMPLE
        New-LocationShortcuts
        Creates a new configuration file with default shortcuts.
    
    .EXAMPLE
        $shortcuts = New-LocationShortcuts -PassThru
        Creates defaults and returns them as a hashtable without console output.
    
    .NOTES
        This will overwrite any existing configuration file without warning.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([hashtable])]
    param(
        [switch]$PassThru
    )

    try {
        $configPath = Get-LocationShortcutsConfigPath
        
        # Confirm before overwriting existing config
        if ((Test-Path -Path $configPath) -and -not $PSCmdlet.ShouldProcess($configPath, 'Overwrite existing configuration')) {
            if ($PassThru) { return Get-LocationShortcuts }
            return
        }

        # Initialize empty hashtable for locations
        $locations = @{}
        
        # Define mappings for user folders that need registry resolution
        # RegName: registry key name in 'User Shell Folders' (null if not in registry)
        # DefaultSub: fallback subfolder name under %USERPROFILE%
        $userFolders = @{
            'Downloads' = @{ RegName = '{374DE290-123F-4565-9164-39C4925E467B}'; DefaultSub = 'Downloads' }
            'Documents' = @{ RegName = 'Personal'; DefaultSub = 'Documents' }
            'Pictures'  = @{ RegName = 'My Pictures'; DefaultSub = 'Pictures' }
            'Music'     = @{ RegName = 'My Music'; DefaultSub = 'Music' }
            'Videos'    = @{ RegName = 'My Video'; DefaultSub = 'Videos' }
            'Scripts'   = @{ RegName = $null; DefaultSub = 'Scripts' }
            'Projects'  = @{ RegName = $null; DefaultSub = 'Projects' }
        }

        # Resolve each user folder path using registry or fallback
        foreach ($folder in $userFolders.GetEnumerator()) {
            $path = Resolve-UserFolder -RegName $folder.Value.RegName -DefaultSub $folder.Value.DefaultSub
            
            # Only add shortcuts for paths that actually exist
            if (Test-Path -Path $path) {
                $locations[$folder.Key] = $path
                Write-Verbose "Added user folder: $($folder.Key) -> $path"
            }
            else {
                Write-Verbose "Skipped non-existent folder: $($folder.Key) ($path)"
            }
        }

        # Add common Windows and system locations
        $staticLocations = @{
            'Home'         = $env:USERPROFILE
            'System'       = "$env:SystemRoot\System32"
            'Programs'     = $env:ProgramFiles
            'Programs32'   = ${env:ProgramFiles(x86)}
            'ProgramData'  = $env:ProgramData
            'Steam'        = "${env:ProgramFiles(x86)}\Steam\steamapps\common"
            'Temp'         = $env:TEMP
            'CTemp'        = 'C:\Temp'
            'Root'         = 'C:\'
        }

        # Add static locations only if they exist
        foreach ($loc in $staticLocations.GetEnumerator()) {
            if (Test-Path -Path $loc.Value) {
                $locations[$loc.Key] = $loc.Value
                Write-Verbose "Added static location: $($loc.Key) -> $($loc.Value)"
            }
            else {
                Write-Verbose "Skipped non-existent location: $($loc.Key) ($($loc.Value))"
            }
        }

        # Save the configuration to disk
        $locations | ConvertTo-Json | Set-Content -Path $configPath -ErrorAction Stop -Encoding UTF8
        Write-Verbose "Saved configuration with $($locations.Count) shortcuts to: $configPath"

        # Return the hashtable if PassThru was specified, otherwise write to host
        if ($PassThru) {
            return $locations
        }
        else {
            Write-Host "Created LocationShortcuts.json with $($locations.Count) shortcuts at: $configPath" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Error creating location shortcuts configuration: $_"
        if ($PassThru) { 
            return @{} 
        }
    }
}

function Set-LocationShortcut {
    <#
    .SYNOPSIS
        Quickly navigates to a frequently used directory using shortcuts.
    
    .DESCRIPTION
        Changes the current working directory to a predefined shortcut location stored in
        the configuration file. Shortcuts are case-insensitive and provide tab-completion.
    
    .PARAMETER Location
        The shortcut name to navigate to. This corresponds to a predefined path in the 
        configuration. Tab-completion is available for valid shortcut names.
    
    .PARAMETER List
        Lists all available shortcuts and their corresponding paths in a formatted table.
        Only shows shortcuts where the target path currently exists.
    
    .PARAMETER Help
        Displays detailed help information for this function.
    
    .EXAMPLE
        Set-LocationShortcut Home
        Changes to the user's home directory (typically C:\Users\Username).
    
    .EXAMPLE
        Set-LocationShortcut -List
        Displays all available shortcuts and their target paths in a table.
    
    .EXAMPLE
        g Projects
        Uses the alias 'g' to navigate to the Projects directory.
    
    .NOTES
        Use the alias 'g' for quick navigation: g Home, g Downloads, etc.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Navigate')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Navigate')]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $shortcuts = Get-LocationShortcuts
            $shortcuts.Keys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        })]
        [string]$Location,

        [Parameter(ParameterSetName = 'List')]
        [switch]$List,
        
        [Parameter(ParameterSetName = 'Help')]
        [switch]$Help
    )

    try {
        # Load shortcuts from configuration
        $locations = Get-LocationShortcuts
        
        # Display help if requested or if no parameters provided
        if ($Help -or ($PSCmdlet.ParameterSetName -eq 'Navigate' -and [string]::IsNullOrWhiteSpace($Location))) {
            Get-Help $MyInvocation.MyCommand.Name -Full
            return
        }

        # Display list of all shortcuts if requested
        if ($List) {
            if ($locations.Count -eq 0) {
                Write-Warning "No location shortcuts configured. Run 'New-LocationShortcuts' to create defaults."
                return
            }

            # Display shortcuts in a formatted table, showing only valid paths
            $locations.GetEnumerator() | 
                Where-Object { Test-Path -Path $_.Value } |
                Sort-Object -Property Name |
                ForEach-Object { 
                    [PSCustomObject]@{ 
                        Shortcut = $_.Name
                        Path     = $_.Value 
                    }
                } |
                Format-Table -AutoSize
            
            return
        }

        # Validate that the requested shortcut exists (case-insensitive)
        $matchingKey = $locations.Keys | Where-Object { $_ -eq $Location }
        
        if (-not $matchingKey) {
            Write-Warning "Unknown location '$Location'. Use 'g -List' to see available shortcuts or 'g -Help' for more information."
            return
        }

        # Get the target path
        $targetPath = $locations[$matchingKey]
        
        # Verify the target path exists before attempting navigation
        if (-not (Test-Path -Path $targetPath)) {
            Write-Warning "Path '$targetPath' for shortcut '$Location' does not exist. The target may have been moved or deleted."
            return
        }

        # Navigate to the target directory
        Set-Location -Path $targetPath
        Write-Verbose "Changed location to: $targetPath"
    }
    catch {
        Write-Error "Error in Set-LocationShortcut: $_"
    }
}

function Add-LocationShortcut {
    <#
    .SYNOPSIS
        Adds a new location shortcut to the configuration.
    
    .DESCRIPTION
        Creates a new shortcut mapping between a name and a filesystem path. The shortcut
        name must be unique and not already exist in the configuration. The target path
        must exist on the filesystem.
    
    .PARAMETER Name
        The shortcut name to create. Must be unique and not contain invalid characters.
        Shortcut names are case-insensitive.
    
    .PARAMETER Path
        The filesystem path this shortcut will point to. Can be a relative or absolute path.
        The path must exist before the shortcut can be created.
    
    .EXAMPLE
        Add-LocationShortcut -Name 'Work' -Path 'C:\Projects\Work'
        Creates a new shortcut named 'Work' pointing to the specified path.
    
    .EXAMPLE
        Add-LocationShortcut -Name 'WebDev' -Path '.\WebProjects'
        Creates a shortcut using a relative path (will be resolved to absolute).
    
    .NOTES
        To modify an existing shortcut, use Edit-LocationShortcut instead.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9_-]+$', ErrorMessage = 'Shortcut name can only contain letters, numbers, hyphens, and underscores.')]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    
    try {
        # Resolve the path to an absolute path
        $resolvedPath = Resolve-Path -Path $Path -ErrorAction Stop | Select-Object -ExpandProperty Path
        
        # Load existing shortcuts
        $configPath = Get-LocationShortcutsConfigPath
        $locations = Get-LocationShortcuts
        
        # Check if shortcut already exists (case-insensitive)
        $existingKey = $locations.Keys | Where-Object { $_ -eq $Name }
        if ($existingKey) {
            Write-Warning "Shortcut '$Name' already exists and points to '$($locations[$existingKey])'. Use Edit-LocationShortcut to modify it."
            return
        }
        
        # Confirm the action
        if (-not $PSCmdlet.ShouldProcess("$Name -> $resolvedPath", 'Add location shortcut')) {
            return
        }
        
        # Add the new shortcut
        $locations[$Name] = $resolvedPath
        
        # Save updated configuration
        $locations | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8 -ErrorAction Stop
        
        Write-Host "Added shortcut '$Name' pointing to '$resolvedPath'" -ForegroundColor Green
        Write-Verbose "Configuration saved to: $configPath"
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Error "Path '$Path' does not exist. Please provide a valid path."
    }
    catch {
        Write-Error "Error adding location shortcut '$Name': $_"
    }
}

function Remove-LocationShortcut {
    <#
    .SYNOPSIS
        Removes a location shortcut from the configuration.
    
    .DESCRIPTION
        Deletes an existing shortcut from the configuration file. This operation is 
        permanent and cannot be undone without manually recreating the shortcut.
    
    .PARAMETER Name
        The name of the shortcut to remove. Must match an existing shortcut name 
        (case-insensitive).
    
    .EXAMPLE
        Remove-LocationShortcut -Name 'Work'
        Removes the shortcut named 'Work' from the configuration.
    
    .EXAMPLE
        Remove-LocationShortcut -Name 'OldProject' -Confirm:$false
        Removes the shortcut without confirmation prompt.
    
    .NOTES
        This operation is permanent. Use -WhatIf to preview the action.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $shortcuts = Get-LocationShortcuts
            $shortcuts.Keys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        })]
        [string]$Name
    )
    
    try {
        # Load existing shortcuts
        $configPath = Get-LocationShortcutsConfigPath
        $locations = Get-LocationShortcuts
        
        # Find matching shortcut (case-insensitive)
        $matchingKey = $locations.Keys | Where-Object { $_ -eq $Name }
        
        if (-not $matchingKey) {
            Write-Warning "Shortcut '$Name' does not exist. Use 'Get-LocationShortcuts' to see available shortcuts."
            return
        }
        
        # Get the path before removal for confirmation message
        $targetPath = $locations[$matchingKey]
        
        # Confirm the action
        if (-not $PSCmdlet.ShouldProcess("$matchingKey -> $targetPath", 'Remove location shortcut')) {
            return
        }
        
        # Remove the shortcut
        $locations.Remove($matchingKey)
        
        # Save updated configuration
        $locations | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8 -ErrorAction Stop
        
        Write-Host "Removed shortcut '$matchingKey'" -ForegroundColor Green
        Write-Verbose "Configuration saved to: $configPath"
    }
    catch {
        Write-Error "Error removing location shortcut '$Name': $_"
    }
}

function Edit-LocationShortcut {
    <#
    .SYNOPSIS
        Edits an existing location shortcut's target path.
    
    .DESCRIPTION
        Updates the filesystem path of an existing shortcut in the configuration. The
        shortcut name must exist, and the new path must be valid and exist on the filesystem.
    
    .PARAMETER Name
        The name of the shortcut to modify. Must match an existing shortcut (case-insensitive).
    
    .PARAMETER NewPath
        The new filesystem path this shortcut should point to. Can be relative or absolute.
        The path must exist before the shortcut can be updated.
    
    .EXAMPLE
        Edit-LocationShortcut -Name 'Work' -NewPath 'D:\NewProjects\Work'
        Updates the 'Work' shortcut to point to a new location.
    
    .EXAMPLE
        Edit-LocationShortcut -Name 'Projects' -NewPath '.\MyProjects'
        Updates using a relative path (will be resolved to absolute).
    
    .NOTES
        The shortcut name cannot be changed. To rename, remove and recreate the shortcut.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $shortcuts = Get-LocationShortcuts
            $shortcuts.Keys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        })]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$NewPath
    )
    
    try {
        # Resolve the new path to an absolute path
        $resolvedPath = Resolve-Path -Path $NewPath -ErrorAction Stop | Select-Object -ExpandProperty Path
        
        # Load existing shortcuts
        $configPath = Get-LocationShortcutsConfigPath
        $locations = Get-LocationShortcuts
        
        # Find matching shortcut (case-insensitive)
        $matchingKey = $locations.Keys | Where-Object { $_ -eq $Name }
        
        if (-not $matchingKey) {
            Write-Warning "Shortcut '$Name' does not exist. Use Add-LocationShortcut to create a new one."
            return
        }
        
        # Get old path for confirmation message
        $oldPath = $locations[$matchingKey]
        
        # Confirm the action
        if (-not $PSCmdlet.ShouldProcess("${matchingKey}: '$oldPath' -> '$resolvedPath'", 'Update location shortcut')) {
            return
        }
        
        # Update the shortcut
        $locations[$matchingKey] = $resolvedPath
        
        # Save updated configuration
        $locations | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8 -ErrorAction Stop
        
        Write-Host "Updated shortcut '$matchingKey' to point to '$resolvedPath'" -ForegroundColor Green
        Write-Verbose "Old path was: $oldPath"
        Write-Verbose "Configuration saved to: $configPath"
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Error "Path '$NewPath' does not exist. Please provide a valid path."
    }
    catch {
        Write-Error "Error editing location shortcut '$Name': $_"
    }
}

#endregion Public Functions

#region Module Initialization

# Create convenient alias for quick navigation
Set-Alias -Name g -Value Set-LocationShortcut

# Export only public functions and the alias
Export-ModuleMember -Function @(
    'Set-LocationShortcut',
    'Add-LocationShortcut',
    'Remove-LocationShortcut',
    'Edit-LocationShortcut',
    'Get-LocationShortcuts',
    'New-LocationShortcuts'
) -Alias 'g'

#endregion Module Initialization