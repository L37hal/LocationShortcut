function Set-LocationShortcut {
    <#
    .SYNOPSIS
    Quickly change location to a set of frequently used directories.
    .DESCRIPTION
    Changes the current directory to a predefined shortcut location.
    .PARAMETER Location
    The shortcut name to jump to.
    .PARAMETER List
    Lists all available shortcuts.
    .PARAMETER Help
    Shows help for this function.
    .EXAMPLE
    Set-LocationShortcut Home
    .EXAMPLE
    Set-LocationShortcut -List
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
    .PARAMETER Name
    Shortcut name.
    .PARAMETER Path
    Filesystem path for the shortcut.
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
    .PARAMETER Name
    Shortcut name to remove.
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
    .PARAMETER Name
    Shortcut name to edit.
    .PARAMETER NewPath
    New path for the shortcut.
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
    #>
    [CmdletBinding()]

    [OutputType([hashtable])]

    param()
    try {
        $configPath = Get-LocationShortcutsConfigPath
        
        if (Test-Path $configPath) {
            $json = Get-Content -Path $configPath -Raw -ErrorAction Stop
            return ($json | ConvertFrom-Json -AsHashtable -ErrorAction Stop)
        }
        
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
    .PARAMETER PassThru
    Returns the hashtable instead of writing to host.
    #>
    [CmdletBinding()]

    param(
        [switch]$PassThru
    )

    try {
        $locations = @{}
        $userFolders = @{
            'Downloads' = @{ RegName = $null; DefaultSub = 'Downloads' }
            'Documents' = @{ RegName = 'Personal'; DefaultSub = 'Documents' }
            'Pictures' = @{ RegName = 'My Pictures'; DefaultSub = 'Pictures' }
            'Music' = @{ RegName = 'My Music'; DefaultSub = 'Music' }
            'Videos' = @{ RegName = 'My Video'; DefaultSub = 'Videos' }
            'Scripts' = @{ RegName = $null; DefaultSub = 'Scripts' }
            'Projects' = @{ RegName = $null; DefaultSub = 'Projects' }
        }

        foreach ($folder in $userFolders.GetEnumerator()) {
            $path = Resolve-UserFolder -RegName $folder.Value.RegName -DefaultSub $folder.Value.DefaultSub
            if (Test-Path $path) {
                $locations[$folder.Key] = $path
            }
        }

        # Add static locations
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
    .PARAMETER RegName
    Registry name in User Shell Folders.
    .PARAMETER DefaultSub
    Default subfolder name.
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