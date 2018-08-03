$apiToken = ''
$url = 'https://api.itglue.com/organizations?sort=id'
#$url = 'https://api.itglue.com/flexible_asset_types?sort=id'

$headers = @{}
$headers.add('cache-control', 'no-cache')
$headers.add('content-type', 'application/vnd.api+json')
$headers.add('x-api-key', "$apiToken")

$a = Invoke-RestMethod -Uri "$url" -Headers $headers