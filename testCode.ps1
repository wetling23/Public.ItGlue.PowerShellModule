$apiToken = ''
#$url = 'https://api.itglue.com/organizations?sort=id'
#$url = 'https://api.itglue.com/flexible_asset_types?sort=id'
#$url = "https://api.itglue.com/flexible_assets?filter[flexible_asset_type_id]=76228"


$table = @{
    "Name" = "GPO1"
    "Link" = $true
}


$Attributes = New-Object PSObject
$Attributes | Add-Member -Type NoteProperty -Name "organization-id" -Value "2536478"
$Attributes | Add-Member -Type NoteProperty -Name "flexible-asset-type-id" -Value "76228"
$Attributes | Add-Member -Type NoteProperty -Name "traits" -Value @{"group-policy-name" = "test1"; "field-2" = (($table | Select-Object @{label = 'Name'; expression = {$_.name}}, @{label = 'Link'; expression = {$_.link}} | ConvertTo-HTML -Fragment -Property 'Name', 'Link') | Out-String); }

$Data = New-Object PSObject
$Data | Add-Member -Type NoteProperty -Name "type" -Value "flexible-assets"
$Data | Add-Member -Type NoteProperty -Name "attributes" -Value $Attributes

$Base = New-Object PSObject
$Base | Add-Member -Type NoteProperty -Name "data" -Value $Data

$headers = @{}
$headers.add('cache-control', 'no-cache')
$headers.add('content-type', 'application/vnd.api+json')
$headers.add('x-api-key', "$apiToken")


$a = Invoke-RestMethod -Uri "https://api.itglue.com/flexible_assets" -Headers $headers -Method POST -Body ($base | ConvertTo-Json -Depth 10)

##107014 == Test AD flexible asset type id
##119883 == Patch Policy flexibile asset type id
##76228 == Active Directory flexible asset type id
##76264 == Server Patching flexible asset type id



$url = "https://api.itglue.com/flexible_asset_types/76264?include=flexible_asset_fields"
$a = Invoke-RestMethod -Uri "$url" -Headers $headers -Method GET

##all orgs
$ItGluePageSize = 1000
$ItGlueUriBase = 'https://api.itglue.com'
$ItGlueApiHeader = @{}
$ItGlueApiHeader.add('content-type', 'application/vnd.api+json')
$ItGlueApiHeader.add('x-api-key', "$apiToken")
$allOrgs = Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/organizations?page[size]=$ItGluePageSize"
$allOrgs = for ($i = 1; $i -le $($allOrgs.meta.'total-pages'); $i++) {
    $queryBody = @{
        "page[size]"                     = $ItGluePageSize
        "page[number]"                   = $i
    }

    (Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/organizations" -Body $queryBody).data
}

##Get field names for a flexible asset
$headers = @{}
$headers.add('content-type', 'application/vnd.api+json')
$headers.add('x-api-key', "$apiToken")
$url = "https://api.itglue.com/flexible_asset_types/76264?include=flexible_asset_fields"
$a = Invoke-RestMethod -Uri "$url" -Headers $headers -Method GET