Function Get-ItGlueFlexibleAssetInstance {
    <#
        .DESCRIPTION
            Gets all instances of a flexible asset, based on the ID.
        .NOTES
            V1.0.0.8 date: 2 July 2019
            V1.0.0.9 date: 11 July 2019
            V1.0.0.10 date: 18 July 2019
            V1.0.0.11 date: 25 July 2019
            V1.0.0.12 date: 30 July 2019
            V1.0.0.13 date: 1 August 2019
            V1.0.0.14 date: 1 August 2019
            V1.0.0.15 date: 6 August 2019
            V1.0.0.16 date: 9 August 2019
            V1.0.0.17 date: 13 August 2019
            V1.0.0.18 date: 11 December 2019
            V1.0.0.19 date: 18 May 2020
            V1.0.0.20 date: 8 July 2020
            V1.0.0.21 date: 7 August 2020
            V2025.04.27.0
            V2025.07.08.0
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER FlexibleAssetId
            Identifier ID for the desired flexible asset type.
        .PARAMETER OrganizationId
            Identifier ID for the desired organization.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER PageSize
            Page size when requesting ITGlue resources via the API. Note that retrieving flexible asset instances is computationally expensive, which may cause a timeout. When that happens, drop the page size down (a lot).
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -FlexibleAssetId 123456 Verbose

            In this example, the cmdlet will get all instances of flexible asset type 123456, using the provided ITGlue API key. Verbose output is sent to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -FlexibleAssetId 123456 -Credential (Get-Credential) -LogPath C:\Temp\log.txt

            In this example, the cmdlet will get all instances of the flexible asset type 123456, using the provided ITGlue user credentials. Output will be written to the log file and host.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -FlexibleAssetId 123456 -OrganizationId 98765 -Credential (Get-Credential) -LogPath C:\Temp\log.txt

            In this example, the cmdlet will get all instances of the flexible asset type 123456, for organization 98765, using the provided ITGlue user credentials. Output will be written to the log file and host.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $True)]
        $FlexibleAssetId,

        [Int]$OrganizationId,

        [Alias("ItGlueUriBase")]
        [string]$UriBase = "https://api.itglue.com",

        [Alias("ItGluePageSize")]
        [int64]$PageSize = 1000,

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    #region Setup
    #region Initialize variables
    $retrievedInstanceCollection = [System.Collections.Generic.List[PSObject]]::New()
    $stopLoop = $false
    $loopCount = 1
    $429Count = 0
    #endregion Initialize variables

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    #region Logging splatting
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $loggingParams = @{
                Verbose        = $true
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $loggingParams = @{
                Verbose = $true
                LogPath = $LogPath
            }
        }
        Else {
            $loggingParams = @{
                Verbose = $true
            }
        }
    }
    Else {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $loggingParams = @{
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $loggingParams = @{
                LogPath = $LogPath
            }
        }
    }
    #endregion Logging splatting

    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $accessToken = Get-ItGlueJsonWebToken -Credential $Credential @loggingParams

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }
    #endregion Setup

    #region Main
    $message = ("{0}: Attempting to determine how many instances there are to be retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    Do {
        Try {
            $message = ("{0}: Sending the following`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ((@{"filter[flexible_asset_type_id]" = "$FlexibleAssetId" }) | Out-String), "$UriBase/flexible_assets?page[size]=$PageSize"); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $queryBody = @{
                "page[number]" = 1
                "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
            }

            If ($OrganizationId) {
                $queryBody.Add("filter[organization_id]", "$OrganizationId")
            }

            $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/flexible_assets" -Body $queryBody -ErrorAction Stop

            $stopLoop = $True

            $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count')); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
        }
        Catch {
            If ($_.Exception.Message -match 429) {
                If ($429Count -lt 9) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                    $429Count++

                    Start-Sleep -Seconds 60
                }
                Else {
                    $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); Out-PsLogging @loggingParams -MessageType Error -Message $message

                    Return "Error"
                }
            }
            Else {
                If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 4, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount); Out-PsLogging @loggingParams -MessageType Warning -Message $message

                    $loopCount++
                }
                Else {
                    $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                    Return "Error"
                }
            }
        }
    }
    While ($stopLoop -eq $false)

    If (-NOT($($instanceTotalCount.meta.'total-count') -gt 0)) {
        $message = ("{0}: Zero instances were identified. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Return
    }

    $page = 1
    $queryBody = $null
    Do {
        $loopCount = 1
        $stopLoop = $False
        $queryBody = @{
            "page[size]"                     = $PageSize
            "page[number]"                   = $page
            "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
        }

        If ($OrganizationId) {
            $queryBody.Add("filter[organization_id]", "$OrganizationId")
        }

        $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.Count, $($instanceTotalCount.meta.'total-count')); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Do {
            Try {
                $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($queryBody | Out-String), "$UriBase/flexible_assets"); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/flexible_assets" -Body $queryBody -ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                $stopLoop = $True
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    If ($429Count -lt 9) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                        $429Count++

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); Out-PsLogging @loggingParams -MessageType Error -Message $message

                        Return "Error"
                    }
                }
                Else {
                    If (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount); Out-PsLogging @loggingParams -MessageType Warning -Message $message

                        $loopCount++

                        If ($loopCount -eq 6) {
                            $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); Out-PsLogging @loggingParams -MessageType Warning -Message $message

                            If ($PageSize -eq 1) {
                                $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

                                # Sometimes, the function returns instance values and the string, "error". Doing this should prevent that.
                                $retrievedInstanceCollection = "Error"

                                Return "Error"
                            }
                            Else {
                                $loopCount = 1
                                $PageSize = $PageSize / 2
                                $page = [math]::Round(($retrievedInstanceCollection.count / $PageSize) + 1)
                                $queryBody = @{
                                    "page[size]"                     = $PageSize
                                    "page[number]"                   = $page
                                    "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
                                }
                            }
                        }
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                        Out-PsLogging @loggingParams -MessageType Error -Message $message

                        Return "Error"
                    }
                }
            }
        }
        While ($stopLoop -eq $false)

        $page++
    }
    While ($retrievedInstanceCollection.Count -lt $instanceTotalCount.meta.'total-count')

    If ($retrievedInstanceCollection.Count -gt $instanceTotalCount.meta.'total-count') {
        $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.Count, $instanceTotalCount.meta.'total-count')
        Out-PsLogging @loggingParams -MessageType Error -Message $message

        Return "Error"
    }
    Else {
        Return $retrievedInstanceCollection
    }
    #endregion Main
} #2025.07.08.0