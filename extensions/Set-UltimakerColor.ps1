
function Ultimaker3_RequestAuthCredentials {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $PrinterAddress
    )

    $Uri = "http://$PrinterAddress/api/v1/auth/request"

    $Fields = @{
        "application"   = "PowerShellSetUltimakerColor";
        "user"          = "PowerShellSetUltimakerColor";
        "host_name"     = "";
        "exclusion_key" = "";
    }

    $Headers = @{
        "Accept" = "application/json"
    }

    return Invoke-WebRequest -Uri $Uri -Method Post -Header $Headers -ContentType "application/x-www-form-urlencoded" -Body $Fields
}

function Ultimaker3_VerifyAuthCredentials {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $PrinterAddress,

        [Parameter(Mandatory=$true)]
        [String]
        $AuthorizationID
    )

    $Uri = "http://$PrinterAddress/api/v1/auth/check/$AuthorizationID"

    $Headers = @{
        "Accept" = "application/json"
    }  

    return Invoke-WebRequest -Uri $Uri -Method Get -Headers $Headers
}

function Ultimaker3_EnsureGlobalAuthCredentials {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $PrinterAddress
    )

    if(-not (Get-Variable -Name ULTIMAKER3_API_ACCESS_CREDENTIALS -Scope Global -ErrorAction SilentlyContinue)) {
        New-Variable -Name ULTIMAKER3_API_ACCESS_CREDENTIALS -Scope Global -Value $null
    }

    $global_credentials_valid = [Boolean]($null -ne $ULTIMAKER3_API_ACCESS_CREDENTIALS)

    if($global_credentials_valid) {
        $credentials_check_response = Ultimaker3_VerifyAuthCredentials -PrinterAddress $PrinterAddress -AuthorizationID $ULTIMAKER3_API_ACCESS_CREDENTIALS.id
        $credentials_check = $credentials_check_response.content | ConvertFrom-Json

        $global_credentials_valid = $credentials_check.message -eq "authorized" 
    }

    if(-not $global_credentials_valid) {
        $credentials_response = Request-Authentication -PrinterAddress $PrinterAddress
        $credentials = $credentials_response.content | ConvertFrom-Json
        
        $credentials_check_response = Ultimaker3_VerifyAuthCredentials -PrinterAddress $PrinterAddress -AuthorizationID $credentials.id
        $credentials_check = $credentials_check_response.content | ConvertFrom-Json

        Write-Host "Waiting for Ultimaker authorization confirmation..."

        while($credentials_check.message -eq "unknown") {
            Start-Sleep -Seconds 1
            $credentials_check_response = Ultimaker3_VerifyAuthCredentials -PrinterAddress $PrinterAddress -AuthorizationID $credentials.id
            $credentials_check = $credentials_check_response | ConvertFrom-Json
        }

        if($credentials_check.message -eq "authorized") {
            Set-Variable -Name ULTIMAKER3_API_ACCESS_CREDENTIALS -Scope Global -Value $credentials
            return $true
        } elseIf($credentials_check.messgae -eq "unauthorized") {
            Write-Host -ForegroundColor Red "The authorization was denied, cannot continue!"
            Set-Variable -Name ULTIMAKER3_API_ACCESS_CREDENTIALS -Scope Global -Value $null
        }
    } else {
        return $true
    }

    return $false
}

function Ultimaker3_SetPrinterLedColor {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $PrinterAddress
    )

    dynamicParam {
        $runtime_parameter_dictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        $runtime_parameter_dictionary.Add("Hue",
            (New-Object System.Management.Automation.RuntimeDefinedParameter("Hue", [Int32], [System.Collections.ObjectModel.Collection[System.Attribute]][Array](
                [System.Management.Automation.ParameterAttribute]@{
                    Mandatory = $true
                },

                (New-Object System.Management.Automation.ValidateSetAttribute(0..360))
            )))
        )

        $runtime_parameter_dictionary.Add("Saturation",
            (New-Object System.Management.Automation.RuntimeDefinedParameter("Saturation", [Int32], [System.Collections.ObjectModel.Collection[System.Attribute]][Array](
                [System.Management.Automation.ParameterAttribute]@{
                    Mandatory = $true
                },

                (New-Object System.Management.Automation.ValidateSetAttribute(0..100))
            )))
        )

        $runtime_parameter_dictionary.Add("Brightness",
            (New-Object System.Management.Automation.RuntimeDefinedParameter("Brightness", [Int32], [System.Collections.ObjectModel.Collection[System.Attribute]][Array](
                [System.Management.Automation.ParameterAttribute]@{
                    Mandatory = $true
                },

                (New-Object System.Management.Automation.ValidateSetAttribute(0..100))
            )))
        )

        return $runtime_parameter_dictionary
    }

    begin {
        $credentials_valid = [Boolean](Ultimaker3_EnsureGlobalAuthCredentials -PrinterAddress $PrinterAddress)
        $Hue = $PSBoundParameters["Hue"]
        $Saturation = $PSBoundParameters["Saturation"]
        $Brightness = $PSBoundParameters["Brightness"]
    }

    process {
        if($credentials_valid) {
            $credentials_id = $ULTIMAKER3_API_ACCESS_CREDENTIALS.id
            $credentials_key = $ULTIMAKER3_API_ACCESS_CREDENTIALS.key

            $uri = "http://$PrinterAddress/api/v1/printer/led"

            $fields = @{
                "hue"        = $Hue;
                "saturation" = $Saturation;
                "brightness" = $Brightness;
            }

            $headers = @{
                "Content-Type" = "application/json";
                "Accept"       = "application/json";
            }

            $credentials_key_secure = ConvertTo-SecureString -String $credentials_key -AsPlainText -Force
            $ps_credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $credentials_id, $credentials_key_secure

            return Invoke-WebRequest -Uri $uri -Method Put -Credential $ps_credentials -Header $headers -ContentType "application/json" -Body ($fields | ConvertTo-Json) -AllowUnencryptedAuthentication
        }
    }
}
