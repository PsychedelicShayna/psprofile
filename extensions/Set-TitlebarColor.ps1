function Set-TitlebarColor{
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $RegistryKey = "HKCU:Software\Microsoft\Windows\DWM",

        [Parameter()]
        [String]
        $EntryName = "AccentColor",

        [Parameter(Mandatory=$true)]
        [Int32]
        $Color
    )

    if(-not (Test-Path $RegistryKey)) {
        Write-Error -Category ResourceUnavailable -ErrorAction Stop `
        -Message "Cannot find registry key `"$RegistryKey`""
    }

    $registry_key_properties = Get-ItemProperty -Path $RegistryKey
    
    if($null -eq $registry_key_properties.AccentColor) {
        Write-Error -ErrorAction Continue "Cannot find `"AccentColor`" property within registry key `"$RegistryKey`" !!"

        if(-not ("y", "yes" -contains (Read-Host -Prompt "Create the AccentColor property at `"$RegistryKey`", and continue?`n[Y] Yes  [N] No`n(default is `"N`"): "))) {
            exit
        }
    }

    Set-ItemProperty -Path $RegistryKey -Name "AccentColor" -Type DWORD -Value 0x00010101    
}

function Set-TitlebarColorBlack {
    [CmdletBinding()]
    param(
        [Parameter()]
        [String]
        $RegistryKey = "HKCU:Software\Microsoft\Windows\DWM",
        
        [Parameter()]
        [String]
        $EntryName = "AccentColor"
    )

    Set-TitlebarColor -RegistryKey $RegistryKey -EntryName $EntryName -Color 0x00010101
}