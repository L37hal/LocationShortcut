#
# Module manifest for module 'LocationShortcuts'
#
# Generated on: 11/02/2025
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'LocationShortcuts.psm1'

    # Version number of this module.
    ModuleVersion = '1.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'a8f3c7d2-4e9b-4a1c-8d5f-2b3e7c9a1f4d'

    # Author of this module
    Author = 'Leigh Butterworth'

    # Company or vendor of this module
    CompanyName = 'Personal'

    # Copyright statement for this module
    Copyright = '(c) 2025. All rights reserved.'

    # Description of the functionality provided by this module
    Description = @'
LocationShortcuts provides a streamlined way to navigate to frequently used directories 
using customizable shortcuts. The module stores shortcuts in a JSON configuration file 
and includes full support for OneDrive redirection, custom user folders, and common 
Windows system locations.

Features:
- Quick navigation using the 'g' alias (e.g., g Home, g Projects)
- Automatic handling of OneDrive-redirected folders
- Tab-completion for shortcut names
- Add, edit, and remove shortcuts dynamically
- List all available shortcuts with their paths
- Default shortcuts for common locations (Documents, Downloads, System32, etc.)
- PowerShell 5.1+ and PowerShell Core compatible
'@

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Set-LocationShortcut',
        'Add-LocationShortcut',
        'Remove-LocationShortcut',
        'Edit-LocationShortcut',
        'Get-LocationShortcuts',
        'New-LocationShortcuts'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @('g')

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    FileList = @(
        'LocationShortcuts.psm1',
        'LocationShortcuts.psd1'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @(
                'Navigation',
                'Directory',
                'Shortcuts',
                'FileSystem',
                'Productivity',
                'Utilities',
                'Windows',
                'OneDrive',
                'CD',
                'Location'
            )

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
Version 1.0.0 (2025-11-02)
--------------------------
Initial release of LocationShortcuts module.

Features:
- Navigate to predefined directory shortcuts using simple commands
- Create, edit, and remove custom shortcuts
- Automatic OneDrive folder detection and handling
- Tab-completion support for shortcut names
- Default shortcuts for common Windows and user folders
- ShouldProcess support for safe operations
- Comprehensive error handling and validation
- Compatible with Windows PowerShell 5.1 and PowerShell 7+

Usage Examples:
- g Home              # Navigate to home directory
- g Projects          # Navigate to Projects folder
- g -List             # Show all available shortcuts
- Add-LocationShortcut -Name "Work" -Path "C:\Work"
- Edit-LocationShortcut -Name "Work" -NewPath "D:\Work"
- Remove-LocationShortcut -Name "Work"

For detailed help on any command:
- Get-Help Set-LocationShortcut -Full
- Get-Help Add-LocationShortcut -Examples
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
