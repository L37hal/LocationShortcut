#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for the LocationShortcuts PowerShell module.

.DESCRIPTION
    Comprehensive test suite for LocationShortcuts module including:
    - Module loading and exports
    - Configuration file operations
    - CRUD operations for shortcuts
    - Navigation functionality
    - Error handling and validation
    - Edge cases and boundary conditions

.NOTES
    File Name      : LocationShortcuts.Tests.ps1
    Prerequisite   : Pester 5.0+
    Author         : PowerShell Module Tests
    
.EXAMPLE
    Invoke-Pester -Path .\LocationShortcuts.Tests.ps1

.EXAMPLE
    Invoke-Pester -Path .\LocationShortcuts.Tests.ps1 -Output Detailed
#>

BeforeAll {
    # Determine the module root directory (parent of Tests folder)
    $ModuleRoot = Split-Path -Path $PSScriptRoot -Parent
    $ModulePath = Join-Path $ModuleRoot 'LocationShortcuts.psm1'
    $ManifestPath = Join-Path $ModuleRoot 'LocationShortcuts.psd1'
    
    # Verify module files exist
    if (-not (Test-Path $ModulePath)) {
        throw "Module file not found: $ModulePath"
    }
    
    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest file not found: $ManifestPath"
    }
    
    # Remove module if already loaded to ensure clean state
    Remove-Module LocationShortcuts -ErrorAction SilentlyContinue
    
    # Import the module
    Import-Module $ModulePath -Force
    
    # Create a temporary test directory for mock paths
    $script:TestRoot = Join-Path $TestDrive 'LocationShortcutsTests'
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
    
    # Create some test directories
    $script:TestPaths = @{
        TestDir1 = Join-Path $script:TestRoot 'TestDir1'
        TestDir2 = Join-Path $script:TestRoot 'TestDir2'
        TestDir3 = Join-Path $script:TestRoot 'TestDir3'
    }
    
    foreach ($path in $script:TestPaths.Values) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

AfterAll {
    # Clean up: Remove the module
    Remove-Module LocationShortcuts -ErrorAction SilentlyContinue
}

Describe 'LocationShortcuts Module' -Tag 'Module' {
    
    Context 'Module Loading' {
        
        It 'Should have a valid module manifest' {
            $ManifestPath = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'LocationShortcuts.psd1'
            Test-Path $ManifestPath | Should -Be $true
            
            # Test manifest is valid
            { Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop } | Should -Not -Throw
        }
        
        It 'Should load the module successfully' {
            Get-Module LocationShortcuts | Should -Not -BeNullOrEmpty
        }
        
        It 'Should export the correct functions' {
            $exportedFunctions = (Get-Module LocationShortcuts).ExportedFunctions.Keys
            $expectedFunctions = @(
                'Set-LocationShortcut',
                'Add-LocationShortcut',
                'Remove-LocationShortcut',
                'Edit-LocationShortcut',
                'Get-LocationShortcuts',
                'New-LocationShortcuts'
            )
            
            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }
        
        It 'Should export the g alias' {
            $alias = Get-Alias -Name 'g' -ErrorAction SilentlyContinue
            $alias | Should -Not -BeNullOrEmpty
            $alias.Definition | Should -Be 'Set-LocationShortcut'
        }
        
        It 'Should have help documentation for all exported functions' {
            $functions = @(
                'Set-LocationShortcut',
                'Add-LocationShortcut',
                'Remove-LocationShortcut',
                'Edit-LocationShortcut',
                'Get-LocationShortcuts',
                'New-LocationShortcuts'
            )
            
            foreach ($function in $functions) {
                $help = Get-Help $function
                $help.Synopsis | Should -Not -BeNullOrEmpty
                $help.Description | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe 'Get-LocationShortcuts' -Tag 'Get' {
    
    Context 'Basic Functionality' {
        
        It 'Should return a hashtable' {
            $result = Get-LocationShortcuts
            $result | Should -BeOfType [hashtable]
        }
        
        It 'Should return shortcuts even on first run' {
            $result = Get-LocationShortcuts
            $result.Count | Should -BeGreaterThan 0
        }
        
        It 'Should include common default shortcuts' {
            $result = Get-LocationShortcuts
            $result.Keys | Should -Contain 'Home'
        }
        
        It 'Should have valid paths for all shortcuts' {
            $result = Get-LocationShortcuts
            foreach ($key in $result.Keys) {
                $result[$key] | Should -Not -BeNullOrEmpty
                $result[$key] | Should -BeOfType [string]
            }
        }
    }
    
    Context 'Error Handling' {
        
        It 'Should handle missing configuration file gracefully' {
            # This should create a new config if missing
            { Get-LocationShortcuts } | Should -Not -Throw
        }
        
        It 'Should return empty hashtable on error' {
            # Mock a scenario where config loading fails
            Mock Get-Content { throw "Simulated error" } -ModuleName LocationShortcuts
            $result = Get-LocationShortcuts
            $result | Should -BeOfType [hashtable]
        }
    }
}

Describe 'New-LocationShortcuts' -Tag 'New' {
    
    Context 'Basic Functionality' {
        
        It 'Should create shortcuts with -PassThru' {
            $result = New-LocationShortcuts -PassThru -Confirm:$false
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -BeGreaterThan 0
        }
        
        It 'Should include standard Windows paths' {
            $result = New-LocationShortcuts -PassThru -Confirm:$false
            $result.Keys | Should -Contain 'Home'
            $result['Home'] | Should -Be $env:USERPROFILE
        }
        
        It 'Should only include paths that exist' {
            $result = New-LocationShortcuts -PassThru -Confirm:$false
            foreach ($path in $result.Values) {
                Test-Path $path | Should -Be $true
            }
        }
        
        It 'Should support ShouldProcess' {
            $command = Get-Command New-LocationShortcuts
            $command.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $command.Parameters.ContainsKey('Confirm') | Should -Be $true
        }
    }
}

Describe 'Add-LocationShortcut' -Tag 'Add' {
    
    BeforeEach {
        # Ensure we have a clean slate
        $shortcuts = Get-LocationShortcuts
        if ($shortcuts.ContainsKey('TestShortcut')) {
            Remove-LocationShortcut -Name 'TestShortcut' -Confirm:$false
        }
    }
    
    Context 'Valid Operations' {
        
        It 'Should add a new shortcut with valid path' {
            { Add-LocationShortcut -Name 'TestShortcut' -Path $script:TestPaths.TestDir1 -Confirm:$false } | 
                Should -Not -Throw
            
            $shortcuts = Get-LocationShortcuts
            $shortcuts.ContainsKey('TestShortcut') | Should -Be $true
            $shortcuts['TestShortcut'] | Should -Be $script:TestPaths.TestDir1
        }
        
        It 'Should resolve relative paths to absolute' {
            Push-Location $script:TestRoot
            try {
                Add-LocationShortcut -Name 'RelativeTest' -Path '.\TestDir1' -Confirm:$false
                $shortcuts = Get-LocationShortcuts
                $shortcuts['RelativeTest'] | Should -Be $script:TestPaths.TestDir1
            }
            finally {
                Pop-Location
                Remove-LocationShortcut -Name 'RelativeTest' -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
        
        It 'Should support ShouldProcess' {
            $command = Get-Command Add-LocationShortcut
            $command.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $command.Parameters.ContainsKey('Confirm') | Should -Be $true
        }
    }
    
    Context 'Parameter Validation' {
        
        It 'Should require Name parameter' {
            # PowerShell's Mandatory attribute prompts for input in interactive mode
            # We need to use a different approach - test the parameter attributes
            $command = Get-Command Add-LocationShortcut
            $nameParam = $command.Parameters['Name']
            $nameParam.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).Mandatory | Should -Contain $true
        }
        
        It 'Should require Path parameter' {
            # PowerShell's Mandatory attribute prompts for input in interactive mode
            # We need to use a different approach - test the parameter attributes
            $command = Get-Command Add-LocationShortcut
            $pathParam = $command.Parameters['Path']
            $pathParam.Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).Mandatory | Should -Contain $true
        }
        
        It 'Should validate shortcut name pattern' {
            # Valid names
            { Add-LocationShortcut -Name 'Valid-Name_123' -Path $script:TestPaths.TestDir1 -Confirm:$false } | 
                Should -Not -Throw
            Remove-LocationShortcut -Name 'Valid-Name_123' -Confirm:$false
            
            # Invalid names with spaces should be caught by pattern validation
            { Add-LocationShortcut -Name 'Invalid Name' -Path $script:TestPaths.TestDir1 -Confirm:$false } | 
                Should -Throw
        }
        
        It 'Should have ValidateNotNullOrEmpty on Name parameter' {
            $command = Get-Command Add-LocationShortcut
            $nameParam = $command.Parameters['Name']
            $hasValidation = $nameParam.Attributes.TypeId.Name -contains 'ValidateNotNullOrEmptyAttribute'
            $hasValidation | Should -Be $true
        }
        
        It 'Should have ValidateNotNullOrEmpty on Path parameter' {
            $command = Get-Command Add-LocationShortcut
            $pathParam = $command.Parameters['Path']
            $hasValidation = $pathParam.Attributes.TypeId.Name -contains 'ValidateNotNullOrEmptyAttribute'
            $hasValidation | Should -Be $true
        }
        
        It 'Should have ValidatePattern on Name parameter' {
            $command = Get-Command Add-LocationShortcut
            $nameParam = $command.Parameters['Name']
            $hasPattern = $nameParam.Attributes.TypeId.Name -contains 'ValidatePatternAttribute'
            $hasPattern | Should -Be $true
        }
    }
    
    Context 'Error Handling' {
        
        It 'Should warn when shortcut already exists' {
            Add-LocationShortcut -Name 'DuplicateTest' -Path $script:TestPaths.TestDir1 -Confirm:$false
            
            # Capture warning
            $result = Add-LocationShortcut -Name 'DuplicateTest' -Path $script:TestPaths.TestDir2 -Confirm:$false -WarningAction SilentlyContinue -WarningVariable warning
            $warning | Should -Not -BeNullOrEmpty
            
            # Clean up
            Remove-LocationShortcut -Name 'DuplicateTest' -Confirm:$false
        }
        
        It 'Should error when path does not exist' {
            $nonExistentPath = Join-Path $script:TestRoot 'DoesNotExist'
            { Add-LocationShortcut -Name 'InvalidPath' -Path $nonExistentPath -Confirm:$false -ErrorAction Stop } | 
                Should -Throw
        }
    }
    
    AfterEach {
        # Clean up test shortcuts
        Remove-LocationShortcut -Name 'TestShortcut' -Confirm:$false -ErrorAction SilentlyContinue
    }
}

Describe 'Remove-LocationShortcut' -Tag 'Remove' {
    
    BeforeEach {
        # Ensure test shortcut exists
        Add-LocationShortcut -Name 'RemoveTest' -Path $script:TestPaths.TestDir1 -Confirm:$false
    }
    
    Context 'Valid Operations' {
        
        It 'Should remove an existing shortcut' {
            { Remove-LocationShortcut -Name 'RemoveTest' -Confirm:$false } | Should -Not -Throw
            
            $shortcuts = Get-LocationShortcuts
            $shortcuts.ContainsKey('RemoveTest') | Should -Be $false
        }
        
        It 'Should be case-insensitive' {
            { Remove-LocationShortcut -Name 'removetest' -Confirm:$false } | Should -Not -Throw
            
            $shortcuts = Get-LocationShortcuts
            $shortcuts.ContainsKey('RemoveTest') | Should -Be $false
        }
        
        It 'Should support ShouldProcess' {
            $command = Get-Command Remove-LocationShortcut
            $command.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $command.Parameters.ContainsKey('Confirm') | Should -Be $true
        }
    }
    
    Context 'Error Handling' {
        
        It 'Should warn when shortcut does not exist' {
            $result = Remove-LocationShortcut -Name 'NonExistentShortcut' -Confirm:$false -WarningAction SilentlyContinue -WarningVariable warning
            $warning | Should -Not -BeNullOrEmpty
        }
    }
    
    AfterEach {
        # Ensure cleanup
        Remove-LocationShortcut -Name 'RemoveTest' -Confirm:$false -ErrorAction SilentlyContinue
    }
}

Describe 'Edit-LocationShortcut' -Tag 'Edit' {
    
    BeforeEach {
        # Create test shortcut
        Add-LocationShortcut -Name 'EditTest' -Path $script:TestPaths.TestDir1 -Confirm:$false
    }
    
    Context 'Valid Operations' {
        
        It 'Should update an existing shortcut path' {
            { Edit-LocationShortcut -Name 'EditTest' -NewPath $script:TestPaths.TestDir2 -Confirm:$false } | 
                Should -Not -Throw
            
            $shortcuts = Get-LocationShortcuts
            $shortcuts['EditTest'] | Should -Be $script:TestPaths.TestDir2
        }
        
        It 'Should resolve relative paths to absolute' {
            Push-Location $script:TestRoot
            try {
                Edit-LocationShortcut -Name 'EditTest' -NewPath '.\TestDir3' -Confirm:$false
                $shortcuts = Get-LocationShortcuts
                $shortcuts['EditTest'] | Should -Be $script:TestPaths.TestDir3
            }
            finally {
                Pop-Location
            }
        }
        
        It 'Should be case-insensitive for shortcut names' {
            { Edit-LocationShortcut -Name 'edittest' -NewPath $script:TestPaths.TestDir2 -Confirm:$false } | 
                Should -Not -Throw
            
            $shortcuts = Get-LocationShortcuts
            $shortcuts['EditTest'] | Should -Be $script:TestPaths.TestDir2
        }
        
        It 'Should support ShouldProcess' {
            $command = Get-Command Edit-LocationShortcut
            $command.Parameters.ContainsKey('WhatIf') | Should -Be $true
            $command.Parameters.ContainsKey('Confirm') | Should -Be $true
        }
    }
    
    Context 'Error Handling' {
        
        It 'Should warn when shortcut does not exist' {
            $result = Edit-LocationShortcut -Name 'NonExistent' -NewPath $script:TestPaths.TestDir1 -Confirm:$false -WarningAction SilentlyContinue -WarningVariable warning
            $warning | Should -Not -BeNullOrEmpty
        }
        
        It 'Should error when new path does not exist' {
            $nonExistentPath = Join-Path $script:TestRoot 'DoesNotExist'
            { Edit-LocationShortcut -Name 'EditTest' -NewPath $nonExistentPath -Confirm:$false -ErrorAction Stop } | 
                Should -Throw
        }
    }
    
    AfterEach {
        # Clean up
        Remove-LocationShortcut -Name 'EditTest' -Confirm:$false -ErrorAction SilentlyContinue
    }
}

Describe 'Set-LocationShortcut' -Tag 'Navigate' {
    
    BeforeAll {
        # Create test shortcut for navigation tests
        Add-LocationShortcut -Name 'NavTest' -Path $script:TestPaths.TestDir1 -Confirm:$false
    }
    
    AfterAll {
        # Clean up test shortcut
        Remove-LocationShortcut -Name 'NavTest' -Confirm:$false -ErrorAction SilentlyContinue
    }
    
    Context 'Navigation' {
        
        It 'Should change location to shortcut path' {
            $originalLocation = Get-Location
            
            Set-LocationShortcut -Location 'NavTest'
            $newLocation = Get-Location
            
            $newLocation.Path | Should -Be $script:TestPaths.TestDir1
            
            # Return to original location
            Set-Location $originalLocation
        }
        
        It 'Should be case-insensitive' {
            $originalLocation = Get-Location
            
            Set-LocationShortcut -Location 'navtest'
            $newLocation = Get-Location
            
            $newLocation.Path | Should -Be $script:TestPaths.TestDir1
            
            Set-Location $originalLocation
        }
        
        It 'Should work with the g alias' {
            $originalLocation = Get-Location
            
            g NavTest
            $newLocation = Get-Location
            
            $newLocation.Path | Should -Be $script:TestPaths.TestDir1
            
            Set-Location $originalLocation
        }
    }
    
    Context 'List Functionality' {
        
        It 'Should list shortcuts with -List parameter' {
            { Set-LocationShortcut -List } | Should -Not -Throw
        }
        
        It 'Should not throw when no shortcuts exist' {
            # This is hard to test without mocking, as Get-LocationShortcuts creates defaults
            # But we can verify the function handles empty hashtables
            Mock Get-LocationShortcuts { return @{} } -ModuleName LocationShortcuts
            { Set-LocationShortcut -List -WarningAction SilentlyContinue } | Should -Not -Throw
        }
    }
    
    Context 'Help Functionality' {
        
        It 'Should display help with -Help parameter' {
            { Set-LocationShortcut -Help } | Should -Not -Throw
        }
        
        It 'Should display help when no parameters provided' {
            { Set-LocationShortcut } | Should -Not -Throw
        }
    }
    
    Context 'Error Handling' {
        
        It 'Should warn when shortcut does not exist' {
            $result = Set-LocationShortcut -Location 'NonExistentShortcut' -WarningAction SilentlyContinue -WarningVariable warning
            $warning | Should -Not -BeNullOrEmpty
        }
        
        It 'Should warn when target path does not exist' {
            # Create a shortcut with a path that we'll delete
            $tempPath = Join-Path $script:TestRoot 'TempDir'
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
            Add-LocationShortcut -Name 'TempShortcut' -Path $tempPath -Confirm:$false
            
            # Delete the directory
            Remove-Item -Path $tempPath -Force
            
            # Try to navigate
            $result = Set-LocationShortcut -Location 'TempShortcut' -WarningAction SilentlyContinue -WarningVariable warning
            $warning | Should -Not -BeNullOrEmpty
            
            # Clean up
            Remove-LocationShortcut -Name 'TempShortcut' -Confirm:$false
        }
    }
}

Describe 'Integration Tests' -Tag 'Integration' {
    
    Context 'Full Workflow' {
        
        It 'Should support complete CRUD workflow' {
            # Create
            Add-LocationShortcut -Name 'WorkflowTest' -Path $script:TestPaths.TestDir1 -Confirm:$false
            $shortcuts = Get-LocationShortcuts
            $shortcuts.ContainsKey('WorkflowTest') | Should -Be $true
            
            # Read
            $shortcuts['WorkflowTest'] | Should -Be $script:TestPaths.TestDir1
            
            # Navigate
            $originalLocation = Get-Location
            Set-LocationShortcut -Location 'WorkflowTest'
            (Get-Location).Path | Should -Be $script:TestPaths.TestDir1
            Set-Location $originalLocation
            
            # Update
            Edit-LocationShortcut -Name 'WorkflowTest' -NewPath $script:TestPaths.TestDir2 -Confirm:$false
            $shortcuts = Get-LocationShortcuts
            $shortcuts['WorkflowTest'] | Should -Be $script:TestPaths.TestDir2
            
            # Delete
            Remove-LocationShortcut -Name 'WorkflowTest' -Confirm:$false
            $shortcuts = Get-LocationShortcuts
            $shortcuts.ContainsKey('WorkflowTest') | Should -Be $false
        }
        
        It 'Should handle multiple shortcuts independently' {
            # Add multiple shortcuts
            Add-LocationShortcut -Name 'Multi1' -Path $script:TestPaths.TestDir1 -Confirm:$false
            Add-LocationShortcut -Name 'Multi2' -Path $script:TestPaths.TestDir2 -Confirm:$false
            Add-LocationShortcut -Name 'Multi3' -Path $script:TestPaths.TestDir3 -Confirm:$false
            
            # Verify all exist
            $shortcuts = Get-LocationShortcuts
            $shortcuts.ContainsKey('Multi1') | Should -Be $true
            $shortcuts.ContainsKey('Multi2') | Should -Be $true
            $shortcuts.ContainsKey('Multi3') | Should -Be $true
            
            # Remove one
            Remove-LocationShortcut -Name 'Multi2' -Confirm:$false
            
            # Verify others still exist
            $shortcuts = Get-LocationShortcuts
            $shortcuts.ContainsKey('Multi1') | Should -Be $true
            $shortcuts.ContainsKey('Multi2') | Should -Be $false
            $shortcuts.ContainsKey('Multi3') | Should -Be $true
            
            # Clean up
            Remove-LocationShortcut -Name 'Multi1' -Confirm:$false
            Remove-LocationShortcut -Name 'Multi3' -Confirm:$false
        }
    }
    
    Context 'Configuration Persistence' {
        
        It 'Should persist shortcuts across function calls' {
            Add-LocationShortcut -Name 'PersistTest' -Path $script:TestPaths.TestDir1 -Confirm:$false
            
            # Get shortcuts in a new call
            $shortcuts = Get-LocationShortcuts
            $shortcuts.ContainsKey('PersistTest') | Should -Be $true
            
            # Clean up
            Remove-LocationShortcut -Name 'PersistTest' -Confirm:$false
        }
    }
}

Describe 'Edge Cases and Boundary Conditions' -Tag 'EdgeCases' {
    
    Context 'Special Characters and Names' {
        
        It 'Should handle shortcuts with hyphens and underscores' {
            Add-LocationShortcut -Name 'Test-Name_123' -Path $script:TestPaths.TestDir1 -Confirm:$false
            $shortcuts = Get-LocationShortcuts
            $shortcuts.ContainsKey('Test-Name_123') | Should -Be $true
            Remove-LocationShortcut -Name 'Test-Name_123' -Confirm:$false
        }
        
        It 'Should handle paths with spaces' {
            $pathWithSpaces = Join-Path $script:TestRoot 'Path With Spaces'
            New-Item -ItemType Directory -Path $pathWithSpaces -Force | Out-Null
            
            Add-LocationShortcut -Name 'SpacePath' -Path $pathWithSpaces -Confirm:$false
            $shortcuts = Get-LocationShortcuts
            $shortcuts['SpacePath'] | Should -Be $pathWithSpaces
            
            Remove-LocationShortcut -Name 'SpacePath' -Confirm:$false
            Remove-Item -Path $pathWithSpaces -Force
        }
    }
    
    Context 'Performance' {
        
        It 'Should handle operations quickly' {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 1; $i -le 10; $i++) {
                Add-LocationShortcut -Name "Perf$i" -Path $script:TestPaths.TestDir1 -Confirm:$false
            }
            
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
            
            # Clean up
            for ($i = 1; $i -le 10; $i++) {
                Remove-LocationShortcut -Name "Perf$i" -Confirm:$false
            }
        }
    }
}