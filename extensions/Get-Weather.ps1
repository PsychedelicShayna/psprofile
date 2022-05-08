function Get-Weather($Location, [Switch]$Response) {
    $request_response = Invoke-WebRequest -Uri "https://wttr.in/$Location"
    return $(if($Response) { $request_response } else { $request_response.Content })
}