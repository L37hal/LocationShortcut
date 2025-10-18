# LocationShortcuts.psm1
# A PowerShell module for managing and quickly navigating to frequently used directories
# using customizable shortcuts stored in a JSON configuration file.

function Set-LocationShortcut {
    <#
    .SYNOPSIS
    Quickly change location to a set of frequently used directories.
    .DESCRIPTION
    Changes the current directory to a predefined shortcut location.
    .PARAMETER Location
    The shortcut name to jump to. This corresponds to a predefined path in the configuration.
    .PARAMETER List
    Lists all available shortcuts and their corresponding paths in a table format.
    .PARAMETER Help
    Shows this help message.
    .EXAMPLE
    Set-LocationShortcut Home
    Changes to the user's home directory.
    .EXAMPLE
    Set-LocationShortcut -List
    Shows all available shortcuts and their paths.
    #>
    [CmdletBinding()]

    param(
        [Parameter(Position=0)]
        [string]$Location,   # The short name key identifying the target path

        [Parameter()]
        [switch]$List,       # When set, list all available shortcuts
        
        [Parameter()]
        [switch]$Help        # When set, display help and return
    )

    try {
        $locations = Get-LocationShortcuts
        
        # If help was requested or no argument provided, show help text and exit.
        if ($Help -or ([string]::IsNullOrEmpty($Location) -and -not $List)) {
            # Get-Help prints the comment-based help defined above.
            Get-Help $MyInvocation.MyCommand.Name
            return
        }

        # If List switch is set, enumerate available shortcuts and display them nicely.
        if ($List) {
            $locations.GetEnumerator() | 
                Where-Object { Test-Path $_.Value } |
                Sort-Object -Property Value |
                ForEach-Object { [PSCustomObject]@{ 
                    Location = $_.Name
                    Path = $_.Value 
                    Valid = Test-Path $_.Value
                }} |
                Format-Table -AutoSize
            return
        }

        # If the provided location key exists in the mapping, change to that path.
        if (-not $locations.ContainsKey($Location)) {
            Write-Warning "Unknown location '$Location'. Use -Help or 'g -List' to see valid options."
            return
        }

        $targetPath = $locations[$Location]
        if (-not (Test-Path $targetPath)) {
            Write-Warning "Path '$targetPath' for location '$Location' does not exist."
            return
        }

        # Use Set-Location (cd) to change the current working directory.
        Set-Location $targetPath
    }
    catch {
        Write-Error "Error in Set-LocationShortcut: $_"
    }
}

function Add-LocationShortcut {
    <#
    .SYNOPSIS
    Adds a new location shortcut.
    .DESCRIPTION
    Creates a new shortcut mapping between a name and a filesystem path.
    .PARAMETER Name
    The shortcut name to create. Must be unique.
    .PARAMETER Path
    The filesystem path this shortcut will point to. Must exist.
    .EXAMPLE
    Add-LocationShortcut -Name "work" -Path "C:\Projects\Work"
    Creates a new shortcut named "work" pointing to the specified path.
    #>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $configPath = Get-LocationShortcutsConfigPath
    $locations = Get-LocationShortcuts
    
    if ($locations.ContainsKey($Name)) {
        Write-Warning "Shortcut '$Name' already exists. Use Edit-LocationShortcut to modify it."
        return
    }
    
    if (-not (Test-Path $Path)) {
        Write-Warning "Path '$Path' does not exist."
        return
    }
    
    $locations[$Name] = $Path
    $locations | ConvertTo-Json | Set-Content $configPath
    Write-Host "Added shortcut '$Name' pointing to '$Path'"
}

function Remove-LocationShortcut {
    <#
    .SYNOPSIS
    Removes a location shortcut.
    .DESCRIPTION
    Deletes an existing shortcut from the configuration.
    .PARAMETER Name
    The name of the shortcut to remove.
    .EXAMPLE
    Remove-LocationShortcut -Name "work"
    Removes the shortcut named "work" from the configuration.
    #>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    $configPath = Get-LocationShortcutsConfigPath
    $locations = Get-LocationShortcuts
    
    if (-not $locations.ContainsKey($Name)) {
        Write-Warning "Shortcut '$Name' does not exist."
        return
    }
    
    $locations.Remove($Name)
    $locations | ConvertTo-Json | Set-Content $configPath
    Write-Host "Removed shortcut '$Name'"
}

function Edit-LocationShortcut {
    <#
    .SYNOPSIS
    Edits an existing location shortcut.
    .DESCRIPTION
    Updates the path of an existing shortcut in the configuration.
    .PARAMETER Name
    The name of the shortcut to modify.
    .PARAMETER NewPath
    The new filesystem path this shortcut should point to. Must exist.
    .EXAMPLE
    Edit-LocationShortcut -Name "work" -NewPath "D:\NewProjects\Work"
    Updates the "work" shortcut to point to a new location.
    #>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$NewPath
    )
    
    $configPath = Get-LocationShortcutsConfigPath
    $locations = Get-LocationShortcuts
    
    if (-not $locations.ContainsKey($Name)) {
        Write-Warning "Shortcut '$Name' does not exist."
        return
    }
    
    if (-not (Test-Path $NewPath)) {
        Write-Warning "Path '$NewPath' does not exist."
        return
    }
    
    $locations[$Name] = $NewPath
    $locations | ConvertTo-Json | Set-Content $configPath
    Write-Host "Updated shortcut '$Name' to point to '$NewPath'"
}

function Get-LocationShortcuts {
    <#
    .SYNOPSIS
    Gets all location shortcuts as a hashtable.
    .DESCRIPTION
    Reads the LocationShortcuts.json configuration file and returns the shortcuts as a hashtable.
    If the file doesn't exist, creates a new one with default shortcuts.
    .OUTPUTS
    System.Collections.Hashtable. A mapping of shortcut names to their filesystem paths.
    .EXAMPLE
    $shortcuts = Get-LocationShortcuts
    Retrieves all configured shortcuts as a hashtable.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]

    param()
    try {
        # Get the path to the config file (handles OneDrive paths correctly)
        $configPath = Get-LocationShortcutsConfigPath
        
        # If config exists, load and parse it as a hashtable
        if (Test-Path $configPath) {
            $json = Get-Content -Path $configPath -Raw -ErrorAction Stop
            return ($json | ConvertFrom-Json -AsHashtable -ErrorAction Stop)
        }
        
        # If no config exists, create new with defaults
        return New-LocationShortcuts -PassThru
    }
    catch {
        Write-Error "Error loading location shortcuts: $_"
        return @{
        }
    }
}

function New-LocationShortcuts {
    <#
    .SYNOPSIS
    Creates or resets the location shortcuts file with defaults.
    .DESCRIPTION
    Generates a new configuration file with default shortcuts for common Windows locations
    and user folders. Existing configuration will be overwritten.
    .PARAMETER PassThru
    When specified, returns the generated shortcuts hashtable instead of writing to host.
    .OUTPUTS
    When -PassThru is specified: System.Collections.Hashtable
    .EXAMPLE
    New-LocationShortcuts
    Creates a new configuration file with default shortcuts.
    .EXAMPLE
    $shortcuts = New-LocationShortcuts -PassThru
    Creates defaults and returns them as a hashtable.
    #>
    [CmdletBinding()]

    param(
        [switch]$PassThru  # Return the hashtable instead of writing to file
    )

    try {
        $locations = @{
        }
        
        # Define mappings for user folders that need special resolution
        # RegName: registry key name in User Shell Folders (null if none)
        # DefaultSub: fallback subfolder name under %USERPROFILE%
        $userFolders = @{
            'Downloads' = @{ RegName = $null; DefaultSub = 'Downloads' }
            'Documents' = @{ RegName = 'Personal'; DefaultSub = 'Documents' }
            'Pictures' = @{ RegName = 'My Pictures'; DefaultSub = 'Pictures' }
            'Music' = @{ RegName = 'My Music'; DefaultSub = 'Music' }
            'Videos' = @{ RegName = 'My Video'; DefaultSub = 'Videos' }
            'Scripts' = @{ RegName = $null; DefaultSub = 'Scripts' }
            'Projects' = @{ RegName = $null; DefaultSub = 'Projects' }
        }

        # Resolve each user folder path using registry or fallback paths
        foreach ($folder in $userFolders.GetEnumerator()) {
            $path = Resolve-UserFolder -RegName $folder.Value.RegName -DefaultSub $folder.Value.DefaultSub
            if (Test-Path $path) {
                $locations[$folder.Key] = $path
            }
        }

        # Add common Windows and system locations that don't need special resolution
        $staticLocations = @{
            'Home' = $env:USERPROFILE
            'System' = "$env:SystemRoot\System32"
            'Programs' = ${env:ProgramFiles}
            'Programs32' = ${env:ProgramFiles(x86)}
            'ProgramData' = $env:ProgramData
            'Steam' = "${env:ProgramFiles(x86)}\Steam\steamapps\common"
            'Temp' = $env:TEMP
            'CTemp' = 'C:\Temp'
            'Root' = 'C:\'
        }

        foreach ($loc in $staticLocations.GetEnumerator()) {
            if (Test-Path $loc.Value) {
                $locations[$loc.Key] = $loc.Value
            }
        }

        $configPath = Get-LocationShortcutsConfigPath
        $locations | ConvertTo-Json | Set-Content $configPath -ErrorAction Stop

        if ($PassThru) {
            return $locations
        }

        Write-Host "Created LocationShortcuts.json at $configPath"
    }
    catch {
        Write-Error "Error creating location shortcuts: $_"
        if ($PassThru) { return @{
        } }
    }
}

function Resolve-UserFolder {
    <#
    .SYNOPSIS
    Resolves a user folder path from registry or fallback.
    .DESCRIPTION
    Attempts to get the correct path for user folders by checking registry keys
    and falling back to default locations if needed.
    .PARAMETER RegName
    The registry value name in User Shell Folders to look up.
    .PARAMETER DefaultSub
    The default subfolder name under %USERPROFILE% to use as fallback.
    .OUTPUTS
    System.String. The resolved filesystem path.
    .EXAMPLE
    Resolve-UserFolder -RegName "Personal" -DefaultSub "Documents"
    Resolves the user's Documents folder path.
    #>
    [CmdletBinding()]

    param(
        [string]$RegName,
        [string]$DefaultSub
    )

    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $docPath = $null

    if (Test-Path $regPath) {
        $reg = Get-ItemProperty -Path $regPath -Name $RegName -ErrorAction SilentlyContinue
        if ($reg -and $reg.$RegName) {
            $expanded = [Environment]::ExpandEnvironmentVariables($reg.$RegName)
            if ([IO.Path]::IsPathRooted($expanded) -and (Test-Path $expanded)) {
                $docPath = $expanded
            }
        }
    }

    if (-not $docPath) {
        $docPath = Join-Path $env:USERPROFILE $DefaultSub
    }

    return $docPath
}

function Get-LocationShortcutsConfigPath {
    <#
    .SYNOPSIS
    Gets the path to the LocationShortcuts.json config file.
    .DESCRIPTION
    Determines the correct path for the config file, handling OneDrive redirection
    and ensuring the containing directory exists.
    .OUTPUTS
    System.String. The full path to LocationShortcuts.json.
    .EXAMPLE
    $configPath = Get-LocationShortcutsConfigPath
    Gets the full path where the configuration file should be stored.
    #>
    [CmdletBinding()]

    param()

    $defaultDocuments = Join-Path $env:USERPROFILE "Documents"
    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $docPath = $null

    if (Test-Path $regPath) {
        $reg = Get-ItemProperty -Path $regPath -Name Personal -ErrorAction SilentlyContinue
        if ($reg -and $reg.Personal) {
            $expanded = [Environment]::ExpandEnvironmentVariables($reg.Personal)
            if ([IO.Path]::IsPathRooted($expanded) -and (Test-Path $expanded)) {
                $docPath = $expanded
            }
        }
    }

    if ($docPath -and ($docPath -match '\\OneDrive(\\| - |$)')) {
        $documentsBase = $docPath
    } else {
        $documentsBase = $defaultDocuments
    }

    $configPath = Join-Path $documentsBase "PowerShell\LocationShortcuts.json"

    # Ensure directory exists
    $configDir = Split-Path $configPath -Parent
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    return $configPath
}

# Aliases
Set-Alias -Name g -Value Set-LocationShortcut

# Export only public functions and alias
Export-ModuleMember -Function @(
    'Set-LocationShortcut',
    'Add-LocationShortcut',
    'Remove-LocationShortcut',
    'Edit-LocationShortcut',
    'Get-LocationShortcuts',
    'New-LocationShortcuts'
) -Alias 'g'