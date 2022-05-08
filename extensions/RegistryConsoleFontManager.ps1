function Get-FontData {
    [CmdletBinding()]param(
        [Alias("Path", "Paths", "FontFolders")]
        [Parameter()]
        [Array]
        $FontDirectories = @("C:\Users\Fedora\AppData\Local\Microsoft\Windows\Fonts",
                             "C:\Windows\Fonts\"),

        [Alias("GetNames", "Name", "FullName")]
        [Parameter()]
        [Switch]
        $FontNames,

        [Parameter()]
        [Switch]
        $AllowDuplicates,

        [Alias("PCoreAsm", "PCoreDLL", "PresentationCoreDLL")]
        [Parameter()]
        [String]
        $PresentationCoreAssembly = "C:\Program Files\PowerShell\7\PresentationCore.dll",
                 
        [Alias("NameFilter", "FileNameFilter", "FileFilter")]
        [Parameter()]
        [ScriptBlock]
        $FontFileNameFilter = { $true },

        [Alias("ObjectFilter", "FontFilter")]
        [Parameter()]
        [ScriptBlock]
        $FontObjectFilter = { $true }
    )

    $Verbose = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent

    Add-Type -Path $PresentationCoreAssembly

    $matching_font_files = `
        $FontDirectories | ForEach-Object {
            (Get-ChildItem $_ | Where-Object {
                     (Test-Path $_ -PathType Leaf) `
                -and $FontFileNameFilter.Invoke($_)
            }).Fullname
        } | Where-Object { 
            $_
        }
    
    $matching_font_objects = @()

    # Loop that populates $matching_font_objects
    foreach($matching_font_file in $matching_font_files) {
        $font_object = New-Object -TypeName Windows.Media.GlyphTypeface $matching_font_file

        # Determine if the font represented by $font_object already exists in $matching_font_objects.
        $font_object_is_duplicate = $false
        if(-not $AllowDuplicates) {
            foreach($existing_font_object in $matching_font_objects) {
                $new_font_object_name      = [String]$font_object.Win32FamilyNames.Value
                $existing_font_object_name = [String]$existing_font_object.Win32FamilyNames.Value

                if($new_font_object_name -eq $existing_font_object_name) {
                    $font_object_is_duplicate = $true
                    break
                }
            }
        }
        
        $verbose_output_fontname_string = [String]"$("[ $($font_object.Win32FamilyNames.Value)".PadRight(60, "_"))] FROM $("[$(Split-Path $matching_font_file -Leaf)".PadRight(120, "_"))]"

        if((-not $font_object_is_duplicate) -and ($FontObjectFilter.Invoke($font_object))) {             
            $matching_font_objects += @($font_object)

            if($Verbose) {
                Write-Host -ForegroundColor Green $verbose_output_fontname_string
            }
        } 

        if($Verbose) {
            Write-Host -ForegroundColor Red $verbose_output_fontname_string
        }
    }
        
    if($FontNames) {
        return $matching_font_objects | ForEach-Object { 
            ([Windows.Media.GlyphTypeface]$_).Win32FamilyNames.Value 
        }
    } else {
        return $matching_font_objects
    }
}

# Determine if a font has already been registered for use with the console in the Windows registry.
function Get-IsConsoleTTFontRegistered {
    [CmdletBinding()]param(
        [Alias("Name")]
        [Parameter()]
        $FontName = $null,
        
        [Alias("ID")]
        [Parameter()]
        $FontID = $null,

        [Alias("Key", "Path")]
        [Parameter()]
        [String]
        $RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont"
    )
    
    if(-not (($null -ne $FontName) -xor ($null -ne $FontID))) {
        throw "Please supply either FontName or FontID as an argument, but not both or neither."
    }

    if($null -ne $FontID) {
        if($FontID.GetType() -notin [String], [Int32]) {
            throw "Invalid type `"$($FontID.GetTypeCode())`" for argument `"FontID`", expected one of: [String], [Int32]"
        }
    
        if($FontID.GetType() -eq [Int32]) {
            $FontID = "$FontID".PadLeft(2, "0")
        }
    }

    $registry_key_values = Get-ItemProperty $RegistryKey | Get-Member

    foreach($value in $registry_key_values) {
        if(($null -ne $FontID) -and ($value.Name -eq $FontID)) {
            return $true
        } 
        
        elseif(($null -ne $FontName) -and ($value.Definition -eq "string $($value.Name)=$FontName")) {
            return $true
        }
    }

    return $false
}

# Generate a new ID for a font that is to be registered for use with the console in the Windows registry.
function Get-NewRegistryConsoleFontId {
    [CmdletBinding()]param(
        [Alias("AsInteger", "Int")]
        [Parameter()]
        [Switch]
        $Integer
    )

    $new_font_id = -1
    $id_exists = $true

    do {
        $new_font_id++
        $id_exists = Get-IsConsoleTTFontRegistered -FontID $new_font_id
    } while($id_exists)

    return $(if($Integer) { $new_font_id } else { "$new_font_id".PadLeft(2, "0") })
}

function Get-ConsoleTTFontNameFromID {
    [CmdletBinding()]param(
        [Alias("ID")]
        [Parameter(Mandatory)]
        $FontID,

        [Alias("Path", "Key")]
        [Parameter()]
        [String]
        $RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont"
    )

    if($FontID.GetType() -notin [String, Int32]) {
        throw "Invalid type `"$($FontID.GetTypeCode())`" for argument `"FontID`", expected one of: [String], [Int32]"
    }

    if($FontID.GetType() -eq [Int32]) {
        $FontID = "$FontID".PadLeft(2, "0")
    }
    
    $registry_key_values = Get-ItemProperty $RegistryKey | Get-Member

    foreach($value in $registry_key_values) {
        if(($value.Name -eq $FontID) -and ($value.Description -match "string $FontID=([\S\s]+)")) {
            return $matches[1]
        }
    }

    return $null
}

function Get-ConsoleTTFontIDFromName {
    [CmdletBinding()]param(
        [Alias("Name")]
        [Parameter(Mandatory)]
        [String]
        $FontName,

        [Parameter()]
        [Switch]
        $Integer,

        [Alias("Path", "Key")]
        [Parameter()]
        [String]
        $RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont"
    )
    
    $registry_key_values = Get-ItemProperty $RegistryKey | Get-Member

    foreach($value in $registry_key_values) {
        if($value.Definition -match "string ([\S\s]+)=$FontName") {
            return $(if($Integer) { [Int32]($matches[1]) } else { $matches[1] });
        }
    }

    return $null
}

function Unregister-ConsoleTTFont {
    [CmdletBinding()]param(
        [Alias("Name")]
        [Parameter()]
        $FontName = $null,

        [Alias("ID")]
        [Parameter()]
        $FontID = $null,

        [Alias("Path", "Key")]
        [Parameter()]
        [String]
        $RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont"
    )

    if(-not (($null -ne $FontName) -xor ($null -ne $FontID))) {
        throw "Please supply either FontName or FontID as an argument, but not both or neither."
    }

    if($null -ne $FontID) {
        $FontName = Get-ConsoleTTFontNameFromID -FontID $FontID -RegistryKey $RegistryKey
    }        
    
    if(Get-IsConsoleTTFontRegistered -FontName $FontName -RegistryKey $RegistryKey) {
        $resolved_font_id = (Get-ConsoleTTFontIDFromName -FontName $FontName -Key $RegistryKey)

        if($null -ne $resolved_font_id) {
            Remove-ItemProperty -Path $RegistryKey -Name $resolved_font_id
            return (-not (Get-IsConsoleTTFontRegistered -FontName $FontName -RegistryKey $RegistryKey))
        } else {
            throw "The font `"$FontName`" cannot be resolved to its ID"
        }
    }

    return $false
}

# Register a font for use with the console in the Windows registry.
function Register-ConsoleTTFont {
    [CmdletBinding()]param(
        [Alias("Name", "Font")]
        [Parameter(Mandatory)]
        [String]
        $FontName,

        [Alias("ID")]
        [Parameter()]
        $FontID = $null,

        [Alias("Force")]
        [Parameter()]
        [Switch]
        $Reregister,

        [Alias("Key", "Path")]
        [Parameter()]
        [String]
        $RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont"
    )

    $initial_font_registered_state = [Boolean](Get-IsConsoleTTFontRegistered -FontName $FontName -RegistryKey $RegistryKey)

    if((Get-IsConsoleTTFontRegistered -FontName $FontName -RegistryKey $RegistryKey) -and (-not $Reregister)) {     
        Write-Error "The font `"$FontName`" is already registered."
        return $null
    }

    if($null -ne $FontID) {
        if($FontID.GetType() -notin [String], [Int32]) {
            throw "Invalid type `"$($FontID.GetTypeCode())`" for argument `"FontID`", expected one of: [String], [Int32]"
        }

        if($FontID.GetType() -eq [Int32]) {
            $FontID = "$FontID".PadLeft(2, "0")
        }
    } else {
        $FontID = Get-NewRegistryConsoleFontId
    }

    if($Reregister -and (Get-IsConsoleTTFontRegistered -FontName $FontName -RegistryKey $RegistryKey)) {
        Unregister-ConsoleTTFont -FontName $FontName -RegistryKey $RegistryKey
    }

    $new_property = New-ItemProperty $RegistryKey -Name $FontID -Type String -Value $FontName    
    
    $end_font_registered_state = [Boolean](Get-IsConsoleTTFontRegistered -FontName $FontName -RegistryKey $RegistryKey)
    
     if (($end_font_registered_state -ne $initial_font_registered_state) `
        -or ($end_font_registered_state -and $Reregister)) {
            return $new_property
        }

    return $null
}

function Get-RegisteredConsoleTTFonts {
    [CmdletBinding()]param(
        [Parameter()]
        [String]
        $RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont"
    )

    $registry_key_values = Get-ItemProperty $RegistryKey | Get-Member

    if($null -ne $registry_key_values) {
        return $registry_key_values  | Where-Object {
                 ($_.Name -match "^\d+$") `
            -and ($_.Definition -match "string $($_.Name)=([\S\s]*)")
        } | ForEach-Object {
            ($_.Definition -match "string $($_.Name)=([\S\s]*)") | Out-Null
            $matches[1]
        }
    }

    return $registry_key_values
}

function Install-NerdFonts() {
    $nf_font_names = Get-FontData   -Verbose `
                                    -FullName `
                                    -FontFileNameFilter {
                                        [CmdletBinding()]param(
                                            [Parameter(Mandatory)]
                                            [String]
                                            $FontFileName
                                        )
    
                                        $FontFileName -match "[\S\s]*nerd[\S\s]*"
                                    } `
                                    -FontObjectFilter {
                                        [CmdletBinding()]param(
                                            [Parameter(Mandatory)]                            
                                            [Windows.Media.GlyphTypeface]
                                            $FontObject
                                        )
    
                                        $FontObject.Win32FamilyNames.Value.ToLower() -match " NF$"
                                    }
    

    Read-Host "Continue?"


    Write-Host $nf_font_names.Win32FamilyNames.Values
}
