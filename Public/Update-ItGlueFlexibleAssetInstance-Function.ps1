Function Update-ItGlueFlexibleAssetInstance {
    <#
        .DESCRIPTION
            Update a flexible asset instance.
        .NOTES
            V2024.09.16.0
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER Id
            Id of the desired Password.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER PageSize
            Page size when requesting ITGlue resources via the API. Note that retrieving asset instances is computationally expensive, which may cause a timeout. When that happens, drop the page size down (a lot).
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> $payload = '{
                "data": {
                    "type": "flexible-assets",
                    "attributes": {
                    "archived": true,
                    "traits": {
                        "domains": 569,
                        "type": "Exchange 2016",
                        "email-servers": [457, 676],
                        "location": "On-Premises",
                        "inbound-delivery": "Office 365",
                        "webmail-url": "https://email.example.com"
                    }
                    }
                }
            }'
            PS C:\> Update-ItGlueFlexibleAssetInstance -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Id 123456 -Payload $payload -Verbose

            In this example, the cmdlet will update the flexible asset with ID 123456 with the properties specified in $payload, using the provided ITGlue API key. Verbose logging output is sent to the host only.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Id')]
    param (
        [Alias("ItGlueApiKey")]
        [Parameter(Mandatory)]
        [SecureString]$ApiKey,

        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [Int]$Id,

        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [String]$Payload,

        [Alias("ItGlueUriBase")]
        [String]$UriBase = "https://api.itglue.com",

        [Alias("ItGluePageSize")]
        [Int64]$PageSize = 1000,

        [Boolean]$BlockStdErr = $false,

        [String]$EventLogSource,

        [String]$LogPath
    )

    #region Setup
    #region Initialize variables
    $stopLoop = $false
    $loopCount = 1
    $429Count = 0
    #endregion Initialize variables

    #region Logging splatting
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $loggingParams = @{
                Verbose        = $true
                EventLogSource = $EventLogSource
            }
        } ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $loggingParams = @{
                Verbose = $true
                LogPath = $LogPath
            }
        } Else {
            $loggingParams = @{
                Verbose = $true
            }
        }
    } Else {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $loggingParams = @{
                EventLogSource = $EventLogSource
            }
        } ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $loggingParams = @{
                LogPath = $LogPath
            }
        } Else {
            $loggingParams = @{}
        }
    }
    #endregion Logging splatting

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    #region Auth
    $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    $header = @{ "x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json" }
    #endregion Auth
    #endregion Setup

    Do {
        Try {
            $response = Invoke-RestMethod -Method PATCH -Headers $header -Uri "$UriBase/flexible_assets/$Id" -Body $Payload -ErrorAction Stop

            $stopLoop = $true
        } Catch {
            If ($_.Exception.Message -match 429) {
                If ($429Count -lt 9) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                    $429Count++

                    Start-Sleep -Seconds 60
                } Else {
                    $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); Out-PsLogging @loggingParams -MessageType Error -Message $message

                    Return "Error"
                }
            } Else {
                If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 4, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount); Out-PsLogging @loggingParams -MessageType Warning -Message $message

                    $loopCount++
                } Else {
                    $message = ("{0}: Unexpected error updated the asset. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                    Return "Error"
                }
            }
        }
    }
    While ($stopLoop -eq $false)

    #region Output
    If ($response.data.id) {
        $message = ("{0}: Successfully updated the flexible asset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Return $response.data
    } Else { "Error" }
    #endregion Output
} #2024.09.16.0