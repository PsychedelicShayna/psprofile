function SPSE_GetExtensions {
    [CmdletBinding()]
    param(
        [Parameter()]
        [Switch]
        $Pretty
    )

    $script_names = [Array](Get-ChildItem $SPSEEnv.repositoryExtensionsDirectory -Name | Where-Object {
        $script_path = Join-Path $SPSEEnv.repositoryExtensionsDirectory $_
        ($_ -match "\.ps1$") -and (Test-Path $script_path -PathType Leaf)
    })

    $script_objects = $script_names | ForEach-Object {
        $script_object = [PSCustomObject]@{
            Name = $_
            Enabled = SPSE_IsExtensionEnabled -Name $_
            FullName = Join-Path $SPSEEnv.repositoryExtensionsDirectory $_
        }

        $script_object.PSObject.Members.Add(
            [System.Management.Automation.PSMemberSet]::new("PSStandardMembers",
                [System.Management.Automation.PSMemberInfo[]][System.Management.Automation.PSPropertySet]::new(
                    "DefaultDisplayPropertySet", [String[]]("Name", "Enabled")
                )
            )
        )

        $script_object | Add-Member -MemberType ScriptMethod -Name "Enable" -Force -Value {
            SPSE_SetExtensionEnabled -Name $this.Name -Enable
        }

        $script_object | Add-Member -MemberType ScriptMethod -Name "Disable" -Force -Value {
            SPSE_SetExtensionEnabled -Name $this.Name -Disable
        }

        $script_object | Add-Member -MemberType ScriptMethod -Name "IsEnabled" -Force -Value {
            SPSE_IsExtensionEnabled -Name $this.Name
        }

        return $script_object
    }

    if($Pretty) {
        foreach($script_object in $script_objects) {
            $color, $glyph = $null, $null

            if($script_object.IsEnabled()) {
                $color = "Green"
                $glyph = "E"
            } else {
                $color = "Red"
                $glyph = "D"
            }

            Write-Host -NoNewline "[ "
            Write-Host -NoNewLine -ForegroundColor $color $glyph
            Write-Host " ] $($script_object.Name)"

        }
    } else {
        return $script_objects
    }
}

function SPSE_RemoveZombieSymlinks {
    $zombie_symlinks = Get-ChildItem $SPSEEnv.enabledUserExtensionsDirectory | ForEach-Object { Get-Item $_ } | Where-Object {
        return ($_.Attributes -match "ReparsePoint") -and (-not (Test-Path $_.LinkTarget))
    }

    foreach($zombie_symlink in $zombie_symlinks) {
        Write-Host "Removing zombie symlink $zombie_symlink"
        Remove-Item $zombie_symlink -Force
    }
}

function SPSE_IsExtensionEnabled {
    [CmdletBinding()]
    param()

    dynamicParam {
        $runtime_parameter_dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $runtime_parameter_dictionary.Add("Name",
            (New-Object System.Management.Automation.RuntimeDefinedParameter("Name", [String], [System.Collections.ObjectModel.Collection[System.Attribute]][Array](
                [System.Management.Automation.ParameterAttribute]@{
                    Mandatory = $true
                    Position  = 1
                },

                (New-Object System.Management.Automation.ValidateSetAttribute(
                    (Get-ChildItem $SPSEEnv.repositoryExtensionsDirectory -Name | Where-Object { (Test-Path -Path (Join-Path $SPSEEnv.repositoryExtensionsDirectory $_) -PathType Leaf) -and ($_ -match "\.ps1$") })
                ))
            )))
        )

        return $runtime_parameter_dictionary
    }

    process {
        $Name = $PSBoundParameters["Name"]
        return Test-Path -Path (Join-Path $SPSEEnv.enabledUserExtensionsDirectory $Name) -PathType Leaf
    }
}

function SPSE_SetExtensionEnabled {
    [CmdletBinding()]
    param(
        [Parameter()]    
        [Switch]
        $Enable,

        [Parameter()]
        [Switch]
        $Disable
    )

    dynamicParam {
        $runtime_parameter_dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $runtime_parameter_dictionary.Add("Name",
            (New-Object System.Management.Automation.RuntimeDefinedParameter("Name", [String], [System.Collections.ObjectModel.Collection[System.Attribute]][Array](
                [System.Management.Automation.ParameterAttribute]@{
                    Mandatory = $true
                    Position  = 1
                },

                (New-Object System.Management.Automation.ValidateSetAttribute(
                    (Get-ChildItem $SPSEEnv.repositoryExtensionsDirectory -Name | Where-Object { (Test-Path -Path (Join-Path $SPSEEnv.repositoryExtensionsDirectory $_) -PathType Leaf) -and ($_ -match "\.ps1$") })
                ))
            )))
        )

        return $runtime_parameter_dictionary
    }

    begin {
        $Name = $PSBoundParameters["Name"]
    }

    process {
        $script_path  = [String](Join-Path $SPSEEnv.repositoryExtensionsDirectory  $Name)
        $symlink_path = [String](Join-Path $SPSEEnv.enabledUserExtensionsDirectory $Name)
    
        if(-not (Test-Path $script_path -PathType Leaf)) {
            Write-Error "Cannot find script '$Name' at location '$script_path'"
            return
        }
    
        if(-not ($Enable -xor $Disable)) {
            Write-Error "Supply either -Enable or -Disable to enable or disable the script '$Name' - not both or neither."
            return
        }
    
        if($Enable -and -not (SPSE_IsExtensionEnabled -Name $Name)) {
            New-Item -ItemType SymbolicLink -Path $symlink_path -Target $script_path | Out-Null
        }
        
        elseIf($Disable -and (SPSE_IsExtensionEnabled -Name $Name)) {
            Remove-Item -Path $symlink_path -Force | Out-Null
        }
    }
}

New-Variable -Name SPSEEnv -Value @{
    repositoryDirectory            = [String]"$HOME\Dropbox\Repositories\shaynas-powershell-extensions"
    repositoryExtensionsDirectory  = [String]"$HOME\Dropbox\Repositories\shaynas-powershell-extensions\extensions"
    enabledUserExtensionsDirectory = [String]"$HOME\shaynas-powershell-extensions\enabled-user-extensions\"
    loadedExtensions               = [Array]@()
}

Write-Host -ForegroundColor Magenta ("< Shayna's PowerShell Extensions >").PadLeft(43, " ")
Write-Host -ForegroundColor Magenta "<$("~"*50)>"

if(-not (Test-Path $SPSEEnv.enabledUserExtensionsDirectory -PathType Container)) {
    Write-Host -ForegroundColor Red "Could not find the powershell-extensions directory for the current user.`nExpecting to find this directory: '$($SPSEEnv.enabledUserExtensionsDirectory)'`n"`

    $create_directory_attempts = 0
    $new_item_error = $null

    do {
        if(-not (Test-Path $SPSEEnv.enabledUserExtensionsDirectory -PathType Container)) {
            Start-Sleep -Milliseconds (100 * $create_directory_attempts)
            Write-Host "Attempt number $create_directory_attempts / 10 to create diectory... '$($SPSEEnv.enabledUserExtensionsDirectory)'"
            New-Item -ItemType Directory $SPSEEnv.enabledUserExtensionsDirectory -Force -ErrorVariable $new_item_error | Out-Null
            ++$create_directory_attempts
        }
    } while(($create_directory_attempts -lt 10) -and (-not (Test-Path $SPSEEnv.enabledUserExtensionsDirectory -PathType Container)))
    
    if(Test-Path $SPSEEnv.enabledUserExtensionsDirectory -PathType Container) {
        Write-Host -ForegroundColor Green "`nCreated '$($SPSEEnv.enabledUserExtensionsDirectory)' successfully."
    } else {    
        Write-Error -Category ResourceUnavailable -Message "`nThis user's symlinks directory still doesn't exist after an attempt was made to create it automatically.`nPlease create this directory manually, or debug this script !!!"`

        if($null -ne $new_item_error) {
            $new_item_error
        }
    }
}


if(Test-Path -Path "HKCU:\Console" -PathType Container) {
    Set-ItemProperty -Path "HKCU:\Console" -Name "VirtualTerminalLevel" -Type DWORD -Value 1
}

# Import enabled PowerShell profile scripts.
foreach($child_item_path in ( Get-Childitem -Path $SPSEEnv.enabledUserExtensionsDirectory -Name `
                            | ForEach-Object { Join-Path $SPSEEnv.enabledUserExtensionsDirectory $_ } `
                            | Where-Object   { Test-Path -Path $_ -PathType Leaf                   } `
                            | Where-Object   { $_ -match "\.ps1$"                                  } `
                            )
       )
{
    Write-Host -NoNewline -ForegroundColor Green "Loading "
    Write-Host -NoNewLine -ForegroundColor Magenta "$((Split-Path $child_item_path -Leaf).PadRight(100, " "))`r"
    
    try {
        Import-Module $child_item_path
    } catch {
        $item_data = Get-Item $child_item_path

        if(($item_data.Attributes -match "ReparsePoint") -and (-not (Test-Path $item_data.LinkTarget))) {
            Write-Error "Possible zombie symlink, cannot import extension `"$child_item_path`""
        } else {
            throw $_
        }
    }
    
    $SPSEEnv.loadedExtensions += $child_item_path 
}

Write-Host -NoNewline -ForegroundColor Green "Finished loading "
Write-Host -NoNewline -ForegroundColor Magenta $SPSEEnv.loadedExtensions.Count
Write-Host -ForegroundColor Green (" extensions.").PadRight(100, " ")

Write-Host -ForegroundColor Magenta "<$("~"*50)>`n"


