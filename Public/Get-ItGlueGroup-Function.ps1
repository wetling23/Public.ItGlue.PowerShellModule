Function Get-ItGlueGroup {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or more groups.
        .NOTES
            V1.0.0.0 date: 12 July 2022
            V1.0.0.1 date: 13 July 2022
            V2025.05.19
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER Id
            Represents the ID of the desired group.
        .PARAMETER Filters
            Represents a hashtable of supported API filters. If non-supported keys are included, the cmdlet will remove them before further processing. As of 13 July 2022, the following values are supported:

            name

            See https://api.itglue.com/developer/#groups-index, for information regarding data types.
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
            PS C:\> Get-ItGlueGroup -Filters @{ name = 'group 1' } -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will get the group called 'group 1', using the provided ITGlue API key. Limited logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueGroup -Filters @{ name = 'group 1' } -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Include users -LogPath C:\Temp\log.txt

            In this example, the cmdlet will get the group called 'group 1', using the provided ITGlue API key. The list of members (ITGlue user object ID) is included. Limited logging output is sent to the host and C:\Temp\log.txt.
         .EXAMPLE
            PS C:\> Get-ItGlueGroup -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Verbose

            In this example, the cmdlet will get all groups from ITGlue, using the provided ITGlue API key. Verbose logging output is sent only to the host.
    #>
    [CmdletBinding(DefaultParameterSetName = 'AllGroups')]
    param (
        [Parameter(ParameterSetName = 'IdFilter', Mandatory)]
        [Int]$Id,

        [Parameter(ParameterSetName = 'HashtableFilter', Mandatory)]
        [Hashtable]$Filter,

        [Alias("ItGlueApiKey")]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [System.Management.Automation.PSCredential]$UserCred,

        [Alias("ItGlueUriBase")]
        [String]$UriBase = "https://api.itglue.com",

        [Alias("ItGluePageSize")]
        [Int64]$PageSize = 1000,

        [ValidateSet( "users", "organizations", "resource_type_restrictions", "my_glue_account")]
        [Switch]$Include,

        [Boolean]$BlockStdErr = $false,

        [String]$EventLogSource,

        [String]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    #region Setup
    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    #region Initialize variables
    $retrievedInstanceCollection = [System.Collections.Generic.List[PSObject]]::New()
    $stopLoop = $false
    $loopCount = 1
    $resourcePath = '/groups'
    switch ($include) {
        "users" { $includeFilter = '?include=users'}
        "organizations" { $includeFilter = '?include=organizations' }
        "resource_type_restrictions" {  $includeFilter = '?include=resource_type_restrictions'}
        "my_glue_account" { $includeFilter = "?include=my_glue_account" }
        Default { $includeFilter = ''}
    }
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

    #region Creds
    If ($ApiKey) {
        $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
    } ElseIf ($UserCred) {
        $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred @loggingParams

        $UriBase = 'https://api-mobile-prod.itglue.com/api'
        $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
    } Else {
        $message = ("{0}: No authentication defined. Re-run the command with either an API key or a user credential." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        Return "Error"
    }
    #endregion Creds
    #endregion Setup

    #region Main
    #region Get data
    Switch ($PsCmdlet.ParameterSetName) {
        "IdFilter" {
            $message = ("{0}: Sending the following:`r`n`tUrl: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$UriBase$resourcePath/$Id")
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase$resourcePath/$Id$userFilter" -ErrorAction Stop

            If ($response.included) {
                Foreach ($item in $response) {
                    $item.data | Add-Member -MemberType NoteProperty -Name included -Value $item.included -Force

                    $retrievedInstanceCollection.Add($item)
                }
            } Else {
                Foreach ($item in $response) {
                    $retrievedInstanceCollection.Add($item)
                }
            }
        }
        { $_ -in @("AllGroups", "HashtableFilter") } {
            #region Parse filters
            If ($Filter) {
                $message = ("{0}: Checking `$Filter for unsupported keys, and removing them." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                $filterClone = $Filter.Clone()
                Foreach ($key in $filterClone.GetEnumerator()) {
                    If ($key.Name -notin @("name")) {
                        $message = ("{0}: Checking `$Filter for unsupported keys, and removing them." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        $Filter.Remove($key.Key)
                    } ElseIf ($key.Name -notmatch 'filter\[.*\]') {
                        $Filter."filter[$($key.Name)]" = $($key.value)
                        $Filter.Remove($key.Key)
                    }
                }
            }
            #endregion Parse filters

            $page = 1
            Do {
                $loopCount = 1
                $stopLoop = $False
                $queryBody = @{
                    "page[size]"   = $PageSize
                    "page[number]" = $page
                }

                $apiFilter = $Filter + $queryBody

                Do {
                    Try {
                        $message = ("{0}: Sending the following:`r`n`tBody:`r`n`t{1}`r`n`tUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($Filter + $queryBody | Out-String).Trim(), "$UriBase$resourcePath")
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase$resourcePath$includeFilter" -Body $apiFilter -ErrorAction Stop

                        $stopLoop = $True
                    } Catch {
                        If ($_.Exception.Message -match 429) {
                            $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            Start-Sleep -Seconds 60
                        } ElseIf (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
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
                                } Else {
                                    $loopCount = 1
                                    $PageSize = $PageSize / 2
                                    $page = [math]::Round(($retrievedInstanceCollection.Count / $PageSize) + 1)
                                    $queryBody = @{
                                        "page[size]"   = $PageSize
                                        "page[number]" = $page
                                    }
                                }
                            }
                        } Else {
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
                While ($stopLoop -eq $false)

                If ($response.included) {
                    Foreach ($item in $response) {
                        $item.data | Add-Member -MemberType NoteProperty -Name included -Value $item.included -Force

                        $retrievedInstanceCollection.Add($item)
                    }
                } Else {
                    Foreach ($item in $response) {
                        $retrievedInstanceCollection.Add($item)
                    }
                }

                $page++
            }
            Until ($null -eq $response.meta.'next-page')
        }
    }
    #endregion Get data

    #region Return
    If (($retrievedInstanceCollection.data.id) -and (-NOT $response.meta.'total-count')) {
        $message = ("{0}: Returning {1} group instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.id.Count)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return $retrievedInstanceCollection.data
    } ElseIf ($retrievedInstanceCollection.data.id.Count -gt $response.meta.'total-count') {
        $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.id.Count, $response.meta.'total-count')
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

        Return "Error"
    } ElseIf ($retrievedInstanceCollection.data.id.Count -eq $response.meta.'total-count') {
        $message = ("{0}: Returning {1} group instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.id.Count)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return $retrievedInstanceCollection.data
    } Else {
        $message = ("{0}: No instances retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        Return "Error"
    }
    #endregion Return
    #endregion Main
} #1.0.0.1