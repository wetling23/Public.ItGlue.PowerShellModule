Function Get-ItGlueDeviceConfig {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or more device configs.
        .NOTES
            V1.0.0.4 date: 2 July 2019
            V1.0.0.5 date: 11 July 2019
            V1.0.0.6 date: 12 July 2019
            V1.0.0.7 date: 18 July 2019
            V1.0.0.8 date: 25 July 2019
            V1.0.0.9 date: 25 July 2019
            V1.0.0.10 date: 30 July 2019
            V1.0.0.11 date: 1 August 2019
            V1.0.0.12 date: 6 August 2019
            V1.0.0.13 date: 9 August 2019
            V1.0.0.14 date: 13 August 2019
            V1.0.0.15 date: 11 December 2019
            V1.0.0.16 date: 18 May 2020
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ComputerName
            Enter the hostname of the desired device config, or "All" to retrieve all device configs.
        .PARAMETER CustomerId
            Desired customer's ITGlue organization ID.
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER PageSize
            Page size when requesting ITGlue resources via the API.
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -ApiKey ITG.XXXXXXXXXXXXX -ComputerName All

            In this example, the cmdlet will get all ITGlue device configurations, using the provided ITGlue API key.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -UserCred (Get-Credential) -ComputerName server1 -Verbose

            In this example, the cmdlet will get all device configurations for "server1", using the provided ITGlue user credentials. Verbose output is sent to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -UserCred (Get-Credential) -ItGlueCustomerId 123456

            In this example, the cmdlet will get all device configurations for customer with ID 123456, using the provided ITGlue user credentials.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [ValidatePattern("^All$|^[a-z,A-Z,0-9]+")]
        [string]$ComputerName,

        [Alias("ItGlueCustomerId")]
        [int64]$CustomerId,

        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

        [Alias("ItGlueUriBase")]
        [string]$UriBase = "https://api.itglue.com",

        [Alias("ItGluePageSize")]
        [int64]$PageSize = 1000,

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Initialize variables.
    $retrievedInstanceCollection = [System.Collections.Generic.List[PSObject]]::New()
    $stopLoop = $false
    $loopCount = 1
    $onlyOneInstance = $false

    # Setup parameters for calling Get-ItGlueJsonWebToken.
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                Verbose        = $true
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $true
                LogPath = $LogPath
            }
        }
        Else {
            $commandParams = @{
                Verbose = $true
            }
        }
    }
    Else {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                LogPath = $LogPath
            }
        }
    }

    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred @commandParams

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    If ($ComputerName -eq "All") {
        $message = ("{0}: Getting all devices configurations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=1" -ErrorAction Stop

                $stopLoop = $True

                $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    Start-Sleep -Seconds 60
                }
                ElseIf (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                }
                Else {
                    $message = ("{0}: Unexpected error getting device configuration assets. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                Error title: {2}`r`n`t
                Error detail is: {3}`r`t`n
                PowerShell returned: {4}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        If (-NOT($($instanceTotalCount.meta.'total-count') -gt 0)) {
            $message = ("{0}: Zero instances were identified. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return
        }

        $page = 1
        Do {
            $loopCount = 1
            $stopLoop = $False
            $queryBody = @{
                "page[size]"   = $PageSize
                "page[number]" = $page
            }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instanceTotalCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    }
                    ElseIf (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++

                        If ($loopCount -eq 6) {
                            $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            If ($PageSize -eq 1) {
                                $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

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
                                [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++
        }
        While ($retrievedInstanceCollection.data.Count -ne $instanceTotalCount.meta.'total-count')

        $message = ("{0}: Found {1} device configurations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.count)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return $retrievedInstanceCollection.data
    }
    ElseIf ($CustomerId -ne $null) {
        $message = ("{0}: Getting devices for customer with ID {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $CustomerId)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=1&filter[organization-id]=$CustomerId" -ErrorAction Stop

                $stopLoop = $True

                $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    Start-Sleep -Seconds 60
                }
                ElseIf (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                }
                Else {
                    $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        If (-NOT($($instanceTotalCount.meta.'total-count') -gt 0)) {
            $message = ("{0}: Zero instances were identified. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return
        }

        $page = 1
        Do {
            $loopCount = 1
            $stopLoop = $False
            $queryBody = @{
                "page[size]"              = $PageSize
                "page[number]"            = $page
                "filter[organization-id]" = $CustomerId
            }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instanceTotalCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($queryBody | Out-String), "$UriBase/flexible_assets")
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    }
                    ElseIf (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++

                        If ($loopCount -eq 6) {
                            $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            If ($PageSize -eq 1) {
                                $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

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
                                [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++

            If (($instanceTotalCount.meta.'total-count' -eq 1) -and ($retrievedInstanceCollection)) {
                $message = ("{0}: There is only one instance, getting ready to return it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                $onlyOneInstance = $true
            }
        }
        While (($retrievedInstanceCollection.data.Count -ne $instanceTotalCount.meta.'total-count') -and ($onlyOneInstance -eq $false))

        If ($ComputerName) {
            $message = ("{0}: Returning devices matching {1} at {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName, $CustomerId)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -match $ComputerName })
        }
        Else {
            $message = ("{0}: Returning devices at {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $CustomerId)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return $retrievedInstanceCollection.data
        }
    }
    ElseIf ($ComputerName -ne $null) {
        $message = ("{0}: Getting all devices configurations with the hostname matching {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $stopLoop = $false
        Do {
            Try {
                $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=1" -ErrorAction Stop

                $stopLoop = $True

                $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    Start-Sleep -Seconds 60
                }
                ElseIf (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                }
                Else {
                    $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        If (-NOT($($instanceTotalCount.meta.'total-count') -gt 0)) {
            $message = ("{0}: Zero instances were identified. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return
        }

        $page = 1
        Do {
            $loopCount = 1
            $stopLoop = $False
            $queryBody = @{
                "page[size]"   = $PageSize
                "page[number]" = $page
            }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instanceTotalCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($queryBody | Out-String), "$UriBase/flexible_assets")
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    }
                    ElseIf (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++

                        If ($loopCount -eq 6) {
                            $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            If ($PageSize -eq 1) {
                                $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

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
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                        Error title: {2}`r`n`t
                        Error detail is: {3}`r`t`n
                        PowerShell returned: {4}" -f `
                                [datetime]::Now, $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++

            If (($instanceTotalCount.meta.'total-count' -eq 1) -and ($retrievedInstanceCollection)) {
                $message = ("{0}: There is only one instance, getting ready to return it." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                $onlyOneInstance = $true
            }
        }
        While (($retrievedInstanceCollection.data.Count -ne $instanceTotalCount.meta.'total-count') -and ($onlyOneInstance -eq $false))

        $message = ("{0}: Found {1} device configurations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $message = ("{0}: Returning devices matching {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -match $ComputerName })
    }
    Else {
        $message = ("{0}: No computer name or customer ID supplied. Please supply a value for one or both parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        Return "Error"
    }
} #1.0.0.16
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
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER FlexibleAssetId
            Identifier ID for the desired flexible asset type.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER PageSize
            Page size when requesting ITGlue resources via the API. Note that retrieving flexible asset instances is computationally expensive, which may cause a timeout. When that happens, drop the page size down (a lot).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -ApiKey ITG.XXXXXXXXXXXXX -FlexibleAssetId 123456 Verbose

            In this example, the cmdlet will get all instances of flexible asset type 123456, using the provided ITGlue API key. Verbose output is sent to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -FlexibleAssetId 123456 -Credential (Get-Credential) -LogPath C:\Temp\log.txt

            In this example, the cmdlet will get all instances of the flexible asset type 123456, using the provided ITGlue user credentials. Output will be written to the log file and host.
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

        [Alias("ItGlueUriBase")]
        [string]$UriBase = "https://api.itglue.com",

        [Alias("ItGluePageSize")]
        [int64]$PageSize = 1000,

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Initialize variables.
    $retrievedInstanceCollection = [System.Collections.Generic.List[PSObject]]::New()
    $stopLoop = $false
    $loopCount = 1

    # Setup parameters for calling Get-ItGlueJsonWebToken.
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                Verbose        = $true
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $true
                LogPath = $LogPath
            }
        }
        Else {
            $commandParams = @{
                Verbose = $true
            }
        }
    }
    Else {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                LogPath = $LogPath
            }
        }
    }

    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $accessToken = Get-ItGlueJsonWebToken -Credential $Credential @commandParams

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    $message = ("{0}: Attempting to determine how many instances there are to be retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Do {
        Try {
            $message = ("{0}: Sending the following`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ((@{"filter[flexible_asset_type_id]" = "$FlexibleAssetId" }) | Out-String), "$UriBase/flexible_assets?page[size]=$PageSize")
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/flexible_assets?page[size]=1" -Body (@{"filter[flexible_asset_type_id]" = "$FlexibleAssetId" }) -ErrorAction Stop

            $stopLoop = $True

            $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
        }
        Catch {
            If ($_.Exception.Message -match 429) {
                $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Start-Sleep -Seconds 60
            }
            ElseIf (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                $message = ("{0}: The request timed out and the loop count is {1} of 4, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                $loopCount++
            }
            Else {
                $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                        [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)

    If (-NOT($($instanceTotalCount.meta.'total-count') -gt 0)) {
        $message = ("{0}: Zero instances were identified. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return
    }

    $page = 1
    Do {
        $loopCount = 1
        $stopLoop = $False
        $queryBody = @{
            "page[size]"                     = $PageSize
            "page[number]"                   = $page
            "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
        }

        $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.Count, $($instanceTotalCount.meta.'total-count'))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($queryBody | Out-String), "$UriBase/flexible_assets")
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/flexible_assets" -Body $queryBody -ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                $stopLoop = $True
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    Start-Sleep -Seconds 60
                }
                ElseIf (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++

                    If ($loopCount -eq 6) {
                        $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        If ($PageSize -eq 1) {
                            $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

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
                            [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        $page++
    }
    While ($retrievedInstanceCollection.Count -ne $instanceTotalCount.meta.'total-count')

    Return $retrievedInstanceCollection
} #1.0.0.19
Function Get-ItGlueJsonWebToken {
    <#
        .DESCRIPTION
            Accept a PowerShell credential object and use it to generate a JSON web token for authentication to the ITGlue API.
        .NOTES
            V1.0.0.0 date: 28 February 2019
                - Initial release.
            V1.0.0.1 date: 2 April 2019
                - Updated in-line documentation.
            V1.0.0.2 date: 24 May 2019
                - Updated formatting.
                - Updated date calculation.
            V1.0.0.3 date: 18 July 2019
            V1.0.0.4 date: 25 July 2019
            V1.0.0.5 date: 1 August 2019
            V1.0.0.6 date: 6 August 2019
            V1.0.0.7 date: 11 December 2019
            V1.0.0.8 date: 18 May 2020
        .PARAMETER Credential
            ITGlue credential object for the desired local account.
        .PARAMETER ItGlueUriBase
            Base URL for the ITGlue customer.
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueJsonWebToken -Credential (Get-Credential) -ItGlueUriBase https://company.itglue.com -Verbose

            In this example, the cmdlet connects to https://company.itglue.com and generates an access token for the user specified in Get-Credential. Verbose output is sent to the host.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $True)]
        [ValidatePattern("^https?:\/\/[a-zA-Z0-9]+\.itglue\.com$")]
        [string]$ItGlueUriBase,

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Initialize variables.
    $ItGlueUriBase = $ItGlueUriBase.TrimEnd('/')

    $message = ("{0}: Step 1, get a refresh token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    #region get refresh token
    $base = [PSCustomObject]@{
        "user" = [PSCustomObject]@{
            "email"    = $Credential.UserName
            "password" = $Credential.GetNetworkCredential().password
        }
    }

    $url = "$ItGlueUriBase/login?generate_jwt=1&sso_disabled=1"
    $headers = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/json' }

    Try {
        $refreshToken = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -Body ($base | ConvertTo-Json) -Method POST -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error getting a refresh token. To prevent errors, {1} will exit. Error details, if present:`r`n`t
        Error title: {2}`r`n`t
        Error detail is: {3}`r`t`n
        PowerShell returned: {4}" -f `
        [datetime]::Now, $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        Return "Error"
    }
    #endregion get refresh token

    #region get access token
    $message = ("{0}: Step 2, get an access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $url = "$ItGlueUriBase/jwt/token?refresh_token=$(($refreshToken.Content | ConvertFrom-Json).token)"
    $headers = @{ 'cache-control' = 'no-cache' }

    Try {
        $accessToken = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -Method GET -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error getting a refresh token. To prevent errors, {1} will exit. The specific error is: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        Return "Error"
    }
    #endregion get access token

    Return $accessToken
} #1.0.0.8
Function Get-ItGlueOrganization {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or organizations.
        .NOTES
            V1.0.0.0 date: 5 April 2019
                - Initial release.
            V1.0.0.1 date: 24 April 2019
                - Added $MaxLoopCount parameter.
            V1.0.0.2 date: 20 May 2019
                - Updated rate-limit detection.
            V1.0.0.3 date: 24 May 2019
                - Updated formatting.
                - Updated date calculation.
            V1.0.0.4 date: 31 May 2019
                - Updated log verbiage.
                - Fixed bug in loop incrementing.
            V1.0.0.5 date: 11 July 2019
            V1.0.0.6 date: 18 July 2019
            V1.0.0.7 date: 25 July 2019
            V1.0.0.8 date: 1 August 2019
            V1.0.0.9 date: 6 August 2019
            V1.0.0.10 date: 9 August 2019
            V1.0.0.11 date: 13 August 2019
            V1.0.0.12 date: 11 December 2019
            V1.0.0.13 date: 18 May 2020
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER CustomerName
            Enter the name of the desired customer, or "All" to retrieve all organizations.
        .PARAMETER CustomerId
            Desired customer's ITGlue organization ID.
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER PageSize
            Page size when requesting ITGlue resources via the API.
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -ItGlueApiKey ITG.XXXXXXXXXXXXX -CustomerName All

            In this example, the cmdlet will get all of the organzations in the instance. Output is sent to the host session and event log.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -UserCred (Get-Credential) -ComputerName company1 -Verbose

            In this example, the cmdlet will get all of the organzations in the instance, with the name "company1". Verbose output is sent to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -UserCred (Get-Credential) -CustomerId 123456 -BlockLogging -LogPath C:\Temp\log.txt

            In this example, the cmdlet will get the customer with ID 123456, using the provided ITGlue user credentials. Output will be written to the log file and host.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [ValidatePattern("^All$|^[a-z,A-Z,0-9]+")]
        [string]$CustomerName,

        [Alias("ItGlueCustomerId")]
        [int64]$CustomerId,

        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

        [Alias("ItGlueUriBase")]
        [string]$UriBase = "https://api.itglue.com",

        [Alias("ItGluePageSize")]
        [int64]$PageSize = 1000,

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Initialize variables.
    $retrievedInstanceCollection = [System.Collections.Generic.List[PSObject]]::New()
    $stopLoop = $false
    $loopCount = 1

    # Setup parameters for calling Get-ItGlueJsonWebToken.
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                Verbose        = $true
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $true
                LogPath = $LogPath
            }
        }
        Else {
            $commandParams = @{
                Verbose = $true
            }
        }
    }
    Else {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                LogPath = $LogPath
            }
        }
    }

    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred @commandParams

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    If (-NOT(($CustomerName) -or ($CustomerId))) {
        $message = ("{0}: No customer name or ID supplied. Defaulting to retrieving all organizations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        $CustomerName = "All"
    }

    If ($CustomerName -eq "All") {
        $message = ("{0}: Getting all organizations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations?page[size]=1" -ErrorAction Stop

                $stopLoop = $True

                $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instancePageCount.meta.'total-count'))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    Start-Sleep -Seconds 60
                }
                ElseIf (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                }
                Else {
                    $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        $page = 1
        Do {
            $loopCount = 1
            $stopLoop = $False
            $queryBody = @{
                "page[size]"   = $PageSize
                "page[number]" = $page
            }

            $message = ("{0}: Body: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($queryBody | Out-String), "$UriBase/flexible_assets")
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    }
                    ElseIf (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++

                        If ($loopCount -eq 6) {
                            $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            If ($PageSize -eq 1) {
                                $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

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
                                [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++
        }
        While ($retrievedInstanceCollection.data.Count -ne $instancePageCount.meta.'total-count')

        $message = ("{0}: Found {1} organizations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.count)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return $retrievedInstanceCollection.data
    }
    ElseIf ($CustomerName) {
        $message = ("{0}: Getting the org, {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $CustomerName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations?page[size]=1" -ErrorAction Stop

                $stopLoop = $True

                $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instancePageCount.meta.'total-count'))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    Start-Sleep -Seconds 60
                }
                ElseIf (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                }
                Else {
                    $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        If (-NOT($($instancePageCount.meta.'total-count') -gt 0)) {
            $message = ("{0}: Too few instances were identified. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return
        }

        $page = 1
        Do {
            $loopCount = 1
            $stopLoop = $False
            $queryBody = @{
                "page[size]"   = $PageSize
                "page[number]" = $page
            }

            $message = ("{0}: Body: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), , ($queryBody | Out-String), "$UriBase/flexible_assets")
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    }
                    ElseIf (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++

                        If ($loopCount -eq 6) {
                            $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            If ($PageSize -eq 1) {
                                $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

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
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                        Error title: {2}`r`n`t
                        Error detail is: {3}`r`t`n
                        PowerShell returned: {4}" -f `
                                [datetime]::Now, $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++
        }
        While ($retrievedInstanceCollection.data.Count -ne $instancePageCount.meta.'total-count')

        $message = ("{0}: Found {1} organizations, filtering for {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $CustomerName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return = ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -eq $CustomerName })
    }
    ElseIf ($CustomerId) {
        $message = ("{0}: Getting organization with ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $CustomerId)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $loopCount = 1
        $stopLoop = $false
        Do {
            Try {
                (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations/$CustomerId"-ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                $stopLoop = $True
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    Start-Sleep -Seconds 60
                }
                If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                }
                ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $CustomerId, $MyInvocation.MyCommand)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
                Else {
                    $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                Error title: {2}`r`n`t
                Error detail is: {3}`r`t`n
                PowerShell returned: {4}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        Return $retrievedInstanceCollection.data
    }
} #1.0.0.13
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
            V1.0.0.15 date: 9 August 2019
            V1.0.0.16 date: 11 December 2019
            V1.0.0.17 date: 18 May 2020
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
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod POST -ApiKey ITG.XXXXXXXXXXXXX

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new flexible asset, using the provided ITGlue API key. The cmdlet will try uploading 5 times.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod POST -ApiKey ITG.XXXXXXXXXXXXX -MaxLoopCount 10

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new flexible asset, using the provided ITGlue API key. The cmdlet will try uploading 10 times.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod PATCH -FlexibleAssetInstanceId 123456 -UserCred (Get-Credential) -Verbose

            In this example, the cmdlet will convert the contents of $uploadData to JSON and update the flexible asset with ID 123456, using the provided ITGlue user credentials. Verbose output is sent to the host.
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

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # We are patching, but don't have a flexible asset instance to patch, request the ID.
    If (($HttpMethod -eq 'PATCH') -and (-NOT($FlexibleAssetInstanceId))) {
        $FlexibleAssetInstanceId = Read-Host -Message "Enter a flexible asset instance ID"
    }

    # Initialize variables.
    $loopCount = 0
    $HttpMethod = $HttpMethod.ToUpper()
    $stopLoop = $false

    # Setup parameters for calling Get-ItGlueJsonWebToken.
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                Verbose        = $true
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $true
                LogPath = $LogPath
            }
        }
        Else {
            $commandParams = @{
                Verbose = $true
            }
        }
    }
    Else {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                LogPath = $LogPath
            }
        }
    }

    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred @commandParams

            $ItGlueUriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    If ($HttpMethod -eq 'PATCH') {
        $message = ("{0}: Preparing URL {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$ItGlueUriBase/flexible_assets/$FlexibleAssetInstanceId")
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $uploadUrl = "$ItGlueUriBase/flexible_assets/$FlexibleAssetInstanceId"
    }
    Else {
        $message = ("{0}: Preparing URL {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$ItGlueUriBase/flexible_assets")
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $uploadUrl = "$ItGlueUriBase/flexible_assets"
    }

    $message = ("{0}: Attempting to upload data to ITGlue (method: {1})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $HttpMethod)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $HttpMethod -Headers $header -Uri $uploadUrl -Body ($Data | ConvertTo-Json -Depth 10) -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
            If ($_.Exception.Message -match 429) {
                $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Start-Sleep -Seconds 60
            }
            If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                $loopCount++
            }
            ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $CustomerId, $MyInvocation.MyCommand)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                Return "Error"
            }
            Else {
                $message = ("{0}: Unexpected error uploading to ITGlue. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                Error title: {2}`r`n`t
                Error detail is: {3}`r`t`n
                PowerShell returned: {4}" -f `
                        [datetime]::Now, $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)

    $response
} #1.0.0.17
Function Out-PsLogging {
    <#
        .DESCRIPTION
            Logging function, for host, event log, or a log file.
        .NOTES
            Author: Mike Hashemi
            V1.0.0.0 date: 3 December 2019
                - Initial release.
            V1.0.0.1 date: 7 January 2020
            V1.0.0.2 date: 22 January 2020
            V1.0.0.3 date: 17 March 2020
        .LINK
            https://github.com/wetling23/logicmonitor-posh-module
        .PARAMETER EventLogSource
            Default parameter set. Represents the Windows Application log event source.
        .PARAMETER LogPath
            Path and file name of the target log file. If the file does not exist, the cmdlet will create it.
        .PARAMETER ScreenOnly
            When this switch parameter is included, the logging output is written only to the host.
        .PARAMETER Message
            Message to output.
        .PARAMETER MessageType
            Type of message to output. Valid values are "Info", "Warning", "Error", and "Verbose". When writing to a log file, all output is "info" but will be written to the host, with the appropriate message type.
        .EXAMPLE
            PS C:\> Out-PsLogging -Message "Test" -MessageType Info -LogPath C:\Temp\log.txt

            In this example, the message, "Test" will be written to the host and appended to C:\Temp\log.txt. If the path does not exist, or the user does not have write access, the message will only be written to the host.
        .EXAMPLE
            PS C:\> Out-PsLogging -Message "Test" -MessageType Warning -EventLogSource TestScript

            In this example, the message, "Test" will be written to the host and to the Windows Application log, as a warning and with the event log source/event ID "TestScript"/5417.
            If the event source does not exist and the session is elevated, the event source will be created.
            If the event source does not exist and the session is not elevated, the message will only be written to the host.
        .EXAMPLE
            PS C:\> Out-PsLogging -Message "Test" -MessageType Verbose -ScreenOnly

            In this example, the message, "Test" will be written to the host as a verbose message.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SessionOnly')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'EventLog')]
        [string]$EventLogSource,

        [ValidateScript( {
                If (-NOT ($_ | Split-Path -Parent | Test-Path) ) {
                    Throw "Path does not exist."
                }
                If (-NOT ($_ | Test-Path) ) {
                    "" | Add-Content -Path $_
                }
                If (-NOT ($_ | Test-Path -PathType Leaf) ) {
                    Throw "The LogPath argument must be a file."
                }
                Return $true
            })]
        [Parameter(Mandatory, ParameterSetName = 'File')]
        [System.IO.FileInfo]$LogPath,

        [switch]$ScreenOnly,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Warning', 'Error', 'Verbose', 'First')]
        [string]$MessageType
    )

    # Initialize variables.
    $elevatedSession = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    If ($PsCmdlet.ParameterSetName -eq "EventLog") {
        If ([System.Diagnostics.EventLog]::SourceExists("$EventLogSource")) {
            # The event source does not exists, nothing else to do.

            $logType = "EventLog"
        }
        ElseIf (-NOT ([System.Diagnostics.EventLog]::SourceExists("$EventLogSource")) -and $elevatedSession) {
            # The event source does not exist, but the session is elevated, so create it.
            Try {
                New-EventLog -LogName Application -Source $EventLogSource -ErrorAction Stop

                $logType = "EventLog"
            }
            Catch {
                Write-Error ("{0}: Unable to create the event source ({1}). No logging will be done." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $EventLogSource)

                $logType = "SessionOnly"
            }
        }
        ElseIf (-NOT $elevatedSession) {
            # The event source does not exist, and the session is not elevated.
            Write-Error ("{0}: The event source ({1}) does not exist and the command was not run in an elevated session, unable to create the event source. No logging will be done." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $EventLogSource)

            $logType = "SessionOnly"
        }
    }
    ElseIf ($PsCmdlet.ParameterSetName -eq "File") {
        # Check if we have rights to the path in $LogPath.
        Try {
            [System.Io.File]::OpenWrite($LogPath).Close()
        }
        Catch {
            Write-Error ("{0}: Unable to write to the log file path ({1}). No logging will be done." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $LogPath)

            $logType = "SessionOnly"
        }

        $logType = "LogFile"
    }
    Else {
        $logType = "SessionOnly"
    }

    Switch ($logType) {
        "SessionOnly" {
            Switch ($MessageType) {
                "Info" { Write-Host $Message }
                "Warning" { Write-Warning $Message }
                "Error" { Write-Error $Message }
                "Verbose" { Write-Verbose $Message -Verbose }
                "First" { Write-Verbose $Message -Verbose }
            }
        }
        "EventLog" {
            Switch ($MessageType) {
                "Info" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $Message -EventId 5417; Write-Host $Message }
                "Warning" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $Message -EventId 5417; Write-Warning $Message }
                "Error" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $Message -EventId 5417; Write-Error $Message }
                "Verbose" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $Message -EventId 5417; Write-Verbose $Message -Verbose }
                "First" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $Message -EventId 5417; Write-Verbose $Message -Verbose }
            }
        }
        "LogFile" {
            Switch ($MessageType) {
                "Info" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]$Message); Write-Host $Message }
                "Warning" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]$Message); Write-Warning $Message }
                "Error" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]$Message); Write-Error $Message }
                "Verbose" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]$Message); Write-Verbose $Message -Verbose }
                "First" { [System.IO.File]::WriteAllLines($LogPath, $Message); Write-Verbose $Message -Verbose }
            }
        }
    }
} #1.0.0.3
Function Remove-ItGlueDeviceConfig {
    <#
        .DESCRIPTION
            Accept a configuration ID and delete it from ITGlue.
        .NOTES
            V1.0.0.0 date: 12 August 2019
                - Initial release.
            V1.0.0.1 date: 11 December 2019
            V1.0.0.2 date: 18 May 2020
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER Id
            Identifier ID for the desired configuration item.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Remove-ItGlueFlexibleAssetInstance -ApiKey ITG.XXXXXXXXXXXXX -Id 123456

            In this example, the cmdlet will remove the configuration with ID 123456, using the provided ITGlue API key.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -Id 123456 -UserCred (Get-Credential) -Verbose

            In this example, the cmdlet will remove the configuration with ID 123456, using the provided ITGlue credentials. Verbose output is sent to the host.
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

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Initialize variables.
    $stopLoop = $false
    $httpVerb = 'DELETE'

    # Setup parameters for calling Get-ItGlueJsonWebToken.
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                Verbose        = $true
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $true
                LogPath = $LogPath
            }
        }
        Else {
            $commandParams = @{
                Verbose = $true
            }
        }
    }
    Else {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                LogPath = $LogPath
            }
        }
    }

    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    $message = ("{0}: Attempting to delete the device configuration with ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $httpVerb -Headers $header -Uri "$UriBase/configurations" -Body ($data | ConvertTo-Json) -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
            If ($_.Exception.Message -match 429) {
                $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Start-Sleep -Seconds 60
            }
            If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                $loopCount++
            }
            ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $CustomerId, $MyInvocation.MyCommand)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                Return "Error"
            }
            Else {
                $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                Error title: {2}`r`n`t
                Error detail is: {3}`r`t`n
                PowerShell returned: {4}" -f `
                        [datetime]::Now, $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)

    Return $response
} #1.0.0.2
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
            V1.0.0.11 date: 19 August 2019
            V1.0.0.12 date: 11 December 2019
            V1.0.0.13 date: 18 May 2020
            V1.0.0.14 date: 11 June 2020
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
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Remove-ItGlueFlexibleAssetInstance -ApiKey ITG.XXXXXXXXXXXXX -Id 123456 -LogPath C:\Temp\log.txt

            In this example, the cmdlet will remove the flexible asset with ID 123456, using the provided ITGlue API key. Output will be written to the log file and host.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -Id 123456 -UserCred (Get-Credential) -Verbose

            In this example, the cmdlet will remove the flexible asset with ID 123456, using the provided ITGlue credentials. Verbose output is sent to the host.
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

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Initialize variables.
    $stopLoop = $false
    $httpVerb = 'DELETE'

    # Setup parameters for calling Get-ItGlueJsonWebToken.
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                Verbose        = $true
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $true
                LogPath = $LogPath
            }
        }
        Else {
            $commandParams = @{
                Verbose = $true
            }
        }
    }
    Else {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                LogPath = $LogPath
            }
        }
    }

    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred @commandParams

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    $message = ("{0}: Attempting to delete the flexible asset with instance: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $httpVerb -Headers $header -Uri "$UriBase/flexible_assets/$Id" -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
            If ($_.Exception.Message -match 429) {
                $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Start-Sleep -Seconds 60
            }
            If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                $loopCount++
            }
            ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                $message = ("{0}: The request to delete flexible asset {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id, $MyInvocation.MyCommand)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                Return "Error"
            }
            Else {
                $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                Error title: {2}`r`n`t
                Error detail is: {3}`r`t`n
                PowerShell returned: {4}" -f `
                        [datetime]::Now, $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)

    Return $response
} #1.0.0.13
Export-ModuleMember -Alias * -Function *
