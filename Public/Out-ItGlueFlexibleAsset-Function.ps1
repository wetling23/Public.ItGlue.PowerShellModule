Function Out-ItGlueFlexibleAsset {
    <#
        .DESCRIPTION
            Accepts a PSCustomObject, converts it to JSON and uploads it to ITGlue. Supports POST and PATCH HTTP methods.
        .NOTES
            V1.0.0.0 date: 21 March 2019
                - Initial release.
            V1.0.0.1 date: 2 April 2019
                - Updated in-line documentation.
            V1.0.0.2 date: 2 April 2019
                - Updated error outpout variable.
            V1.0.0.3 date: 2 April 2019
                - Fixed bug in variable validation.
            V1.0.0.4 date: 6 April 2019
                - Added support for rate-limiting response.
            V1.0.0.5 date: 18 April 2019
                - Updated how we check for rate-limit response.
            V1.0.0.6 date: 24 April 2019
                - Added $MaxLoopCount parameter.
            V1.0.0.7 date: 20 May 2019
                - Updated rate-limit detection.
            V1.0.0.8 date: 24 May 2019
                - Updated formatting.
                - Updated date calculation.
            V1.0.0.9 date: 11 July 2019
            V1.0.0.10 date: 18 July 2019
            V1.0.0.11 date: 24 July 2019
            V1.0.0.12 date: 25 July 2019
            V1.0.0.13 date: 1 August 2019
            V1.0.0.14 date: 6 August 2019
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER Data
            Custom PSObject containing flexible asset properties.
        .PARAMETER HttpMethod
            Used to dictate whether the cmdlet should use POST or PATCH when sending data to ITGlue.
        .PARAMETER FlexibleAssetInstanceId
            When included, is used to update (PATCH) a specifc instance of a flexible asset.
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod POST -ApiKey ITG.XXXXXXXXXXXXX

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new flexible asset, using the provided ITGlue API key. The cmdlet will try uploading 5 times. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod POST -ApiKey ITG.XXXXXXXXXXXXX -MaxLoopCount 10

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new flexible asset, using the provided ITGlue API key. The cmdlet will try uploading 10 times. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod PATCH -FlexibleAssetInstanceId 123456 -UserCred (Get-Credential) -BlockLogging -Verbose

            In this example, the cmdlet will convert the contents of $uploadData to JSON and update the flexible asset with ID 123456, using the provided ITGlue user credentials. Output will only be sent to the host session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$Data,

        [Parameter(Mandatory = $True)]
        [ValidateSet('POST', 'PATCH')]
        [string]$HttpMethod,

        [int64]$FlexibleAssetInstanceId,

        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

        [string]$ItGlueUriBase = "https://api.itglue.com",

        [string]$EventLogSource = 'ItGluePowerShellModule',

        [switch]$BlockLogging
    )

    If (-NOT($BlockLogging)) {
        $return = Add-EventLogSource -EventLogSource $EventLogSource

        If ($return -ne "Success") {
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f [datetime]::Now, $EventLogSource)
            Write-Verbose $message

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    $message = ("{0}: Operating in the {1} parameterset." -f [datetime]::Now, $PsCmdlet.ParameterSetName)
    If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # We are patching, but don't have a flexible asset instance to patch, request the ID.
    If (($HttpMethod -eq 'PATCH') -and (-NOT($FlexibleAssetInstanceId))) {
        $FlexibleAssetInstanceId = Read-Host -Message "Enter a flexible asset instance ID"
    }

    # Initialize variables.
    $loopCount = 0
    $HttpMethod = $HttpMethod.ToUpper()
    $stopLoop = $false
    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f [datetime]::Now)
            If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f [datetime]::Now)
            If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred

            $ItGlueUriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    If ($HttpMethod -eq 'PATCH') {
        $message = ("{0}: Preparing URL {1}." -f [datetime]::Now, "$ItGlueUriBase/flexible_assets/$FlexibleAssetInstanceId")
        If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $uploadUrl = "$ItGlueUriBase/flexible_assets/$FlexibleAssetInstanceId"
    }
    Else {
        $message = ("{0}: Preparing URL {1}." -f [datetime]::Now, "$ItGlueUriBase/flexible_assets")
        If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $uploadUrl = "$ItGlueUriBase/flexible_assets"
    }

    $message = ("{0}: Attempting to upload data to ITGlue (method: {1})." -f [datetime]::Now, $HttpMethod)
    If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $HttpMethod -Headers $header -Uri $uploadUrl -Body ($Data | ConvertTo-Json -Depth 10) -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
            If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f [datetime]::Now, $loopCount)
                If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                $loopCount++
            }
            ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                $message = ("{0}: The request for {1} timed out. {2} will exit." -f [datetime]::Now, $CustomerId, $MyInvocation.MyCommand)
                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
            Else {
                $message = ("{0}: Unexpected error uploading to ITGlue. To prevent errors, {1} will exit. If present, the error detail is: {2} PowerShell returned: {3}" -f `
                        [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)

    $response
} #1.0.0.14