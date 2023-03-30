Function Get-ItGlueLocation {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or locations.
        .NOTES
            V1.0.0.0 date: 16 July 2020
            V1.0.0.1 date: 7 August 2020
            V2023.02.08.0
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER Id
            Enter the instance ID of the desired location asset.
        .PARAMETER OrganizationName
            Enter the name of the desired customer, or "All" to retrieve all locations.
        .PARAMETER OrganizationId
            Desired customer's ITGlue organization ID.
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER PageSize
            Page size when requesting ITGlue resources via the API.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueLocation -ApiKey $ItGlueApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will retrieve all instances of the location asset type. Limited logging output is sent only to the session host.
        .EXAMPLE
            PS C:\> Get-ItGlueLocation -UserCred (Get-Credential) -Id 111111 -Verbose

            In this example, the cmdlet will retrieve the instance of the location asset type with ID 111111. Verbose logging output is sent only to the session host.
        .EXAMPLE
            PS C:\> Get-ItGlueLocation -ItGlueApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -OrganizationId 111111 -Verbose -LogPath C:\Temp\log.txt

            In this example, the cmdlet will retrieve all location instances associated with the organization with ID 111111. Verbose logging output is sent to the session host and C:\Temp\log.txt
        .EXAMPLE
            PS C:\> Get-ItGlueLocation -ItGlueApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -OrganizationName "Acme Corp" -Verbose -LogPath C:\Temp\log.txt

            In this example, the cmdlet will retrieve all location instances associated with the organization named "Acme Corp". Verbose logging output is sent to the session host and C:\Temp\log.txt
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [int64]$Id,

        [ValidatePattern("^All$|^[a-z,A-Z,0-9]+")]
        [Alias("CustomerName")]
        [string]$OrganizationName,

        [Alias("ItGlueCustomerId")]
        [int64]$OrganizationId,

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

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    #region Setup
    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # Initialize variables.
    $retrievedInstanceCollection = [System.Collections.Generic.List[PSObject]]::New()
    $stopLoop = $false
    $loopCount = 1
    $429Count = 0

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
    #endregion Setup

    #region Main
    If (-NOT(($OrganizationName) -or ($OrganizationId) -or ($Id))) {
        $message = ("{0}: No customer name or ID supplied. Defaulting to retrieving all locations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $OrganizationName = "All"
    }

    If ($OrganizationName -eq "All") {
        $message = ("{0}: Getting all locations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/locations?page[size]=1" -ErrorAction Stop

                $stopLoop = $True

                $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instancePageCount.meta.'total-count'))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    If ($429Count -lt 9) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        $429Count++

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                    }
                }
                Else {
                    If (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }
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

            $message = ("{0}: Body: {1}`r`n`tUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($queryBody | Out-String), "$UriBase/flexible_assets")
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/locations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        If (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                            $loopCount++

                            If ($loopCount -eq 6) {
                                $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                                If ($PageSize -eq 1) {
                                    $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                                    # Sometimes, the function returns instance values and the string, "error". Doing this should prevent that.
                                    $retrievedInstanceCollection = "Error"

                                    Return "Error"
                                }
                                Else {
                                    $loopCount = 1
                                    $PageSize = $PageSize / 2
                                    $page = [math]::Round(($retrievedInstanceCollection.count / $PageSize) + 1)
                                    $queryBody = @{
                                        "page[size]"   = $PageSize
                                        "page[number]" = $page
                                    }
                                }
                            }
                        }
                        Else {
                            $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                            Return "Error"
                        }
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++
        }
        While ($retrievedInstanceCollection.data.Count -lt $instancePageCount.meta.'total-count')

        If ($retrievedInstanceCollection.data.Count -gt $instancePageCount.meta.'total-count') {
            $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.data.Count, $instancePageCount.meta.'total-count')
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        $message = ("{0}: Found {1} locations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.count)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return $retrievedInstanceCollection.data
    }
    ElseIf ($OrganizationName) {
        $message = ("{0}: Getting locations for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrganizationName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/locations?page[size]=1" -ErrorAction Stop

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
                Else {
                    If (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }
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

            $message = ("{0}: Body: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), , ($queryBody | Out-String), "$UriBase/locations")
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/locations" -Body $queryBody -ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        If (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                            $loopCount++

                            If ($loopCount -eq 6) {
                                $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                                If ($PageSize -eq 1) {
                                    $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                                    # Sometimes, the function returns instance values and the string, "error". Doing this should prevent that.
                                    $retrievedInstanceCollection = "Error"

                                    Return "Error"
                                }
                                Else {
                                    $loopCount = 1
                                    $PageSize = $PageSize / 2
                                    $page = [math]::Round(($retrievedInstanceCollection.count / $PageSize) + 1)
                                    $queryBody = @{
                                        "page[size]"   = $PageSize
                                        "page[number]" = $page
                                    }
                                }
                            }
                        }
                        Else {
                            $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                        Error title: {2}`r`n`t
                        Error detail is: {3}`r`t`n
                        PowerShell returned: {4}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                            Return "Error"
                        }
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++
        }
        While ($retrievedInstanceCollection.Count -lt $instancePageCount.meta.'total-count')

        If ($retrievedInstanceCollection.Count -gt $instancePageCount.meta.'total-count') {
            $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.Count, $instancePageCount.meta.'total-count')
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        $message = ("{0}: Found {1} locations, filtering for {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $OrganizationName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return ($retrievedInstanceCollection | Where-Object { $_.attributes.'organization-name' -eq $OrganizationName })
    }
    ElseIf ($OrganizationId) {
        $message = ("{0}: Getting locations for customer with ID {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrganizationId)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations/$OrganizationId/relationships/locations" -ErrorAction Stop

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
                Else {
                    If (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }
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

            $message = ("{0}: Body: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), , ($queryBody | Out-String), "$UriBase/locations")
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations/$OrganizationId/relationships/locations" -Body $queryBody -ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        If (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                            $loopCount++

                            If ($loopCount -eq 6) {
                                $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                                If ($PageSize -eq 1) {
                                    $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                                    # Sometimes, the function returns instance values and the string, "error". Doing this should prevent that.
                                    $retrievedInstanceCollection = "Error"

                                    Return "Error"
                                }
                                Else {
                                    $loopCount = 1
                                    $PageSize = $PageSize / 2
                                    $page = [math]::Round(($retrievedInstanceCollection.count / $PageSize) + 1)
                                    $queryBody = @{
                                        "page[size]"   = $PageSize
                                        "page[number]" = $page
                                    }
                                }
                            }
                        }
                        Else {
                            $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                    Error title: {2}`r`n`t
                    Error detail is: {3}`r`t`n
                    PowerShell returned: {4}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                            Return "Error"
                        }
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++
        }
        While ($retrievedInstanceCollection.Count -lt $instancePageCount.meta.'total-count')

        If ($retrievedInstanceCollection.Count -gt $instancePageCount.meta.'total-count') {
            $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.Count, $instancePageCount.meta.'total-count')
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        $message = ("{0}: Found {1} locations, filtering for {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $OrganizationName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return $retrievedInstanceCollection
    }
    ElseIf ($Id) {
        $message = ("{0}: Getting location with ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/locations/$Id"-ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                $stopLoop = $True
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    Start-Sleep -Seconds 60
                }
                Else {
                    If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    }
                    ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                        $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrganizationId, $MyInvocation.MyCommand)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                Error title: {2}`r`n`t
                Error detail is: {3}`r`t`n
                PowerShell returned: {4}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }
                }
            }
        }
        While ($stopLoop -eq $false)

        Return $retrievedInstanceCollection
    }
    #endregion Main
} #2023.02.08.0