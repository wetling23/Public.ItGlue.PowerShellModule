Function Remove-ItGlueFlexibleAssetInstance {
    <#
        .DESCRIPTION
            Accept a flexible asset ID and delete it from ITGlue.
        .NOTES
            V1.0.0.0 date: 11 April 2019
                - Initial release.
            V1.0.0.1 date: 24 April 2019
                - Added $MaxLoopCount parameter.
            V1.0.0.2 date: 20 May 2019
                - Updated rate-limit detection.
            V1.0.0.3 date: 24 May 2019
                - Updated formatting.
                - Updated date calculation.
            V1.0.0.4 date: 11 July 2019
            V1.0.0.5 date: 18 July 2019
            V1.0.0.6 date: 25 July 2019
            V1.0.0.7 date: 1 August 2019
            V1.0.0.8 date: 6 August 2019
            V1.0.0.9 date: 8 August 2019
            V1.0.0.10 date: 9 August 2019
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER Id
            Identifier ID for the desired flexible asset type.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Remove-ItGlueFlexibleAssetInstance -ApiKey ITG.XXXXXXXXXXXXX -Id 123456

            In this example, the cmdlet will remove the flexible asset with ID 123456, using the provided ITGlue API key. Output is written to the session host and the Windows event log.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -Id 123456 -UserCred (Get-Credential) -BlockLogging -Verbose

            In this example, the cmdlet will remove the flexible asset with ID 123456, using the provided ITGlue credentials. Output is written to the session host only
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

        [Parameter(Mandatory = $True, ValueFromPipeline)]
        $Id,

        [Alias("ItGlueUriBase")]
        [string]$UriBase = "https://api.itglue.com",

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

    # Initialize variables.
    $stopLoop = $false
    $httpVerb = 'DELETE'
    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f [datetime]::Now)
            If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ItGlueApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f [datetime]::Now)
            If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    $message = ("{0}: Attempting to delete the flexible asset with instance: {1}." -f [datetime]::Now, $Id)
    If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $httpVerb -Headers $header -Uri "$UriBase/flexible_assets/$Id" -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
            If ($_.Exception.Message -match 429) {
                $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f [datetime]::Now)
                If (($BlockLogging) -AND (($PSBoundParameters['Verbose']) -or $VerbosePreference -eq 'Continue')) { Write-Verbose $message } ElseIf (($PSBoundParameters['Verbose']) -or ($VerbosePreference -eq 'Continue')) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

                Start-Sleep -Seconds 60
            }
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
                $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                        [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)

    Return $response
} #1.0.0.10