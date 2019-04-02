Function Get-ItGlueFlexibleAssetInstance {
    <#
        .DESCRIPTION
            Gets all instances of a flexible asset, based on the ID.
        .NOTES
            V1.0.0.0 date: 21 March 2019
                - Initial release.
            V1.0.0.1 date: 2 April 2019
                - Updated in-line documentation.
        .PARAMETER ItGlueApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER ItGlueUserCred
            ITGlue credential object for the desired local account.
        .PARAMETER FlexibleAssetId
            Identifier ID for the desired flexible asset type.
        .PARAMETER ItGlueUriBase
            Base URL for the ITGlue API.
        .PARAMETER ItGluePageSize
            Page size when requesting ITGlue resources via the API. Note that retrieving flexible asset instances is computationally expensive, which may cause a timeout. When that happens, drop the page size down (a lot).
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -ItGlueApiKey ITG.XXXXXXXXXXXXX -FlexibleAssetId 123456

            In this example, the cmdlet will get all instances of flexible asset type 123456, using the provided ITGlue API key. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -FlexibleAssetId 123456 -ItGlueUserCred (Get-Credential) -BlockLogging -Verbose

            In this example, the cmdlet will get all instances of the flexible asset type 123456, using the provided ITGlue user credentials. Output will only be sent to the host session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ITGlueApiKey')]
    param (
        [Parameter(ParameterSetName = 'ITGlueApiKey', Mandatory)]
        [SecureString]$ItGlueApiKey,

        [Parameter(ParameterSetName = 'ITGlueUserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$ItGlueUserCred,

        [Parameter(Mandatory = $True)]
        $FlexibleAssetId,

        [string]$ItGlueUriBase = "https://api.itglue.com",

        [int64]$ItGluePageSize = 1000,

        [string]$EventLogSource = 'ItGluePowerShellModule',

        [switch]$BlockLogging
    )

    If (-NOT($BlockLogging)) {
        $return = Add-EventLogSource -EventLogSource $EventLogSource

        If ($return -ne "Success") {
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
            Write-Verbose $message

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

    $message = ("{0}: Operating in the {1} parameterset." -f (Get-Date -Format s), $PsCmdlet.ParameterSetName)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

    # Initialize variables.
    Switch ($PsCmdlet.ParameterSetName) {
        'ITGlueApiKey' {
            $message = ("{0}: Setting header with API key." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            $ItGlueApiHeader = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ItGlueApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'ITGlueUserCred' {
            $message = ("{0}: Setting header with user-access token." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

            $accessToken = Get-ItGlueJsonWebToken -Credential $ItGlueUserCred

            $ItGlueUriBase = 'https://api-mobile-prod.itglue.com/api'
            $ItGlueApiHeader = @{}
            $ItGlueApiHeader.add('cache-control', 'no-cache')
            $ItGlueApiHeader.add('content-type', 'application/vnd.api+json')
            $ItGlueApiHeader.add('authorization', "Bearer $(($accessToken.Content | ConvertFrom-Json).token)")
        }
    }

    $message = ("Attempting to retrieve all Active Directory flexible assets from ITGlue.")
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

    Try {
        $allExistingActiveDirectories = Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/flexible_assets?page[size]=$ItGluePageSize" -Body (@{"filter[flexible_asset_type_id]" = "$FlexibleAssetId"}) -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error retrieving all Active Directory flexible assets from ITGlue. To prevent errors, {1} will exit. The error is: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
        If ($BlockLogging) {Write-Error $message -ForegroundColor Red} Else {Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417}

        Return
    }

    $allExistingActiveDirectories = for ($i = 1; $i -le $($allExistingActiveDirectories.meta.'total-pages'); $i++) {
        $adQueryBody = @{
            "page[size]"                     = $ItGluePageSize
            "page[number]"                   = $i
            #"filter[organization_id]"        = "$ItGlueCustomerId" This line can come out eventually. I just don't want to remove it yet. It is not required for this function (obviously).
            "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
        }

        $message = ("Getting page {0} of {1} of Active Directory flexible assets." -f $i, $($allExistingActiveDirectories.meta.'total-pages'))
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417}

        (Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/flexible_assets" -Body $adQueryBody -ErrorAction Stop).data
    }

    Return $allExistingActiveDirectories
} #1.0.0.1