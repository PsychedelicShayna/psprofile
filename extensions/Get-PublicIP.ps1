function Get-PublicIP([Switch]$Json, [Switch]$Xml, [Switch]$JsonResponse, [Switch]$XmlResponse) {
    if($JsonResponse) { return  Invoke-WebRequest -Uri "https://wtfismyip.com/json"         }
    if($XmlResponse)  { return  Invoke-WebRequest -Uri "https://wtfismyip.com/xml"          }
    if($Xml)          { return (Invoke-WebRequest -Uri "https://wtfismyip.com/xml").Content }

    $response = Invoke-WebRequest -Uri "https://wtfismyip.com/json"
    $public_ip_info = $response.Content | ConvertFrom-Json

    if($Json) { return $response.Content }

    return [PSCustomObject]@{
        "IPAddress"   = $public_ip_info.YourFuckingIPAddress
        "Location"    = $public_ip_info.YourFuckingLocation
        "ISP"         = $public_ip_info.YourFuckingISP
        "Hostname"    = $public_ip_info.YourFuckingHostname
        "TorExit"     = $public_ip_info.YourFuckingTorExit
        "CountryCode" = $public_ip_info.YourFuckingCountryCode
    }
}