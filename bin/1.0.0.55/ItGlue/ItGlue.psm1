﻿Function Get-ItGlueContact {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or more contacts.
        .NOTES
            V1.0.0.0 date: 16 November 2021
            V1.0.0.1 date: 12 July 2022
            V1.0.0.2 date: 22 July 2022
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ContactId
            Represents the ID of the desired contact instance.
        .PARAMETER Filters
            Represents a hashtable of supported API filters. If non-supported keys are included, the cmdlet will remove them before further processing. As of 16 November 2021, the following values are supported:

            id, first_name, last_name, title, contact_type_id, important, primary_email, organization_id, psa_id, psa_integration_type (manage, autotask, tigerpaw, kaseya-bms, pulseway-psa, vorex)

            See https://api.itglue.com/developer/#contacts-index, for information regarding data types.
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
            PS C:\> Get-ItGlueContact -Filters @{ organization_id = 456 } -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will get the contact(s) associated with the organization with ID 456, using the provided ITGlue API key. Limited logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueContact -ContactId 123 -UserCred (Get-Credential)

            In this example, the cmdlet will get the contact with ID 123, using the provided ITGlue user credentials. Limited logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueContact -Filter @{ id = 123 } -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will get the contact with ID 123, using the provided ITGlue API key. Limited logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueContact -Filter @{ id = "123,890" } -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will get the contacts with ID 123 and 890, using the provided ITGlue API key. Limited logging output is sent only to the host.
         .EXAMPLE
            PS C:\> Get-ItGlueContact -Filter @{ first_name = "John"; last_name = "Doe" } -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -LogPath C:\Temp\log.txt

            In this example, the cmdlet will get the contact(s) with first name "John" and last name "Doe", using the provided ITGlue API key. Limited logging output is sent to the host and C:\Temp\log.txt.
         .EXAMPLE
            PS C:\> Get-ItGlueContact -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Verbose

            In this example, the cmdlet will get all contacts from ITGlue, using the provided ITGlue API key. Verbose logging output is sent only to the host.

pecific names
    #>
    [CmdletBinding(DefaultParameterSetName = 'AllContacts')]
    param (
        [Parameter(ParameterSetName = 'ContactIdFilter', Mandatory)]
        [Int64]$ContactId,

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

        [Boolean]$BlockStdErr = $false,

        [String]$EventLogSource,

        [String]$LogPath
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

    # Setup parameters for calling Get-ItGlueJsonWebToken.
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                Verbose        = $true
                EventLogSource = $EventLogSource
            }
        } ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $true
                LogPath = $LogPath
            }
        } Else {
            $commandParams = @{
                Verbose = $true
            }
        }
    } Else {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $commandParams = @{
                EventLogSource = $EventLogSource
            }
        } ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                LogPath = $LogPath
            }
        }
    }

    If ($ApiKey) {
        $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
    } ElseIf ($UserCred) {
        $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred @commandParams

        $UriBase = 'https://api-mobile-prod.itglue.com/api'
        $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
    } Else {
        $message = ("{0}: No authentication defined. Re-run the command with either an API key or a user credential." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

        Return "Error"
    }
    #endregion Setup

    #region Main
    Switch ($PsCmdlet.ParameterSetName) {
        {$_ -in ("HashtableFilter", "AllContacts")} {
            #region Parse filters
            If ($Filter) {
                $message = ("{0}: Checking `$Filter for unsupported keys, and removing them." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                $filterClone = $Filter.Clone()
                Foreach ($key in $filterClone.GetEnumerator()) {
                    If ($key.Name -notin @("id", "first_name", "last_name", "title", "contact_type_id", "important", "primary_email", "organization_id", "psa_id", "psa_integration_type")) {
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
                        $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($Filter + $queryBody | Out-String), "$UriBase/flexible_assets")
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/contacts" -Body $apiFilter -ErrorAction Stop

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
                                        "page[size]"                     = $PageSize
                                        "page[number]"                   = $page
                                        "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
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
                            $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                            Return "Error"
                        }
                    }
                }
                While ($stopLoop -eq $false)

                Foreach ($item in $response.data) {
                    $retrievedInstanceCollection.Add($item)
                }

                $page++
            }
            Until ($response.meta.'next-page' -eq $null)

            If ($retrievedInstanceCollection.id.Count -gt $response.meta.'total-count') {
                $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.id.Count, $response.meta.'total-count')
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }

            If ($retrievedInstanceCollection.id) {
                $message = ("{0}: Returning {1} Contact instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.id.Count)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Return $retrievedInstanceCollection
            } Else {
                $message = ("{0}: No instances retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                Return "Error"
            }
        }
        "ContactIdFilter" {
            $loopCount = 1
            $stopLoop = $False

            Do {
                Try {
                    $message = ("{0}: Sending the following:`r`nBody:`r`n`t{1}`r`n`tUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($Filter + $queryBody | Out-String).Trim(), "$UriBase/contacts/$ContactId")
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/contacts/$ContactId" -ErrorAction Stop

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
                                    "page[size]"                     = $PageSize
                                    "page[number]"                   = $page
                                    "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
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
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            If ($response.data.id) {
                $message = ("{0}: Successfully retrieved contact properties, returning the contact." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return $response.data
            }
            Else {
                $message = ("{0}: No contact returned for ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ContactId)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }
        }
    }
    #endregion Main
} #1.0.0.2
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
            V1.0.0.17 date: 8 July 2020
            V1.0.0.18 date: 7 August 2020
            V1.0.0.19 date: 7 August 2020
            V1.0.0.20 date: 11 November 2021
            V1.0.0.21 date: 16 November 2021
            V1.0.0.22 date: 24 November 2021
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ComputerName
            Enter the hostname of the desired device config, or "All" to retrieve all device configs.
        .PARAMETER OrganizationId
            Desired customer's ITGlue organization ID.
        .PARAMETER Filters
            Represents a hashtable of supported API filters. If non-supported keys are included, the cmdlet will remove them before further processing. As of 11 November 2021, the following values are supported:

            id, name, organization_id, configuration_type_id, configuration_status_id, contact_id, serial_number, asset_tag, psa_id, psa_integration_type (manage, autotask, tigerpaw, kaseya-bms, pulseway-psa, vorex), rmm_id, rmm_integration_type (addigy, aem, atera, auvik, managed-workplace, continuum, jamf-pro, kaseya-vsa, automate, log-me-in, msp-rmm, meraki, msp-n-central, ninja-rmm, panorama9, pulseway-rmm, syncro, watchman-monitoring), archived

            See https://api.itglue.com/developer/#configurations-index, for information regarding data types.
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
            PS C:\> Get-ItGlueDeviceConfig -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -ComputerName All

            In this example, the cmdlet will get all ITGlue device configurations, using the provided ITGlue API key.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -UserCred (Get-Credential) -ComputerName server1 -Verbose

            In this example, the cmdlet will get all device configurations for "server1", using the provided ITGlue user credentials. Verbose logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -UserCred (Get-Credential) -ItGlueOrganizationId 123456

            In this example, the cmdlet will get all device configurations for customer with ID 123456, using the provided ITGlue user credentials. Limited logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -Filters @{ id = 123 } -LogPath C:\Temp\log.txt

            In this example, the cmdlet will get the configuration with ID 123. Limited logging output is sent to the host and C:\Temp\log.txt.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -Filters @{ name = 'server1'; organization_id = 456 }

            In this example, the cmdlet will get the configuration(s) with name 'server1', associated with the organization with ID 456. Limited logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -Filters @{ name = 'server1'; organization_id = 456; archived = 'false' }

            In this example, the cmdlet will get the configuration(s) with name 'server1', associated with the organization with ID 456 and which are not archived. Limited logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -Filters @{ configuration_type_id = 789 }

            In this example, the cmdlet will get all configurations with type ID 789. Limited logging output is sent only to the host.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [ValidatePattern("^All$|^[a-z,A-Z,0-9]+")]
        [string]$ComputerName,

        [Alias("ItGlueCustomerId", "CustomerId")]
        [int64]$OrganizationId,

        [Alias("Filters")]
        [hashtable]$Filter,

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
    #endregion Setup

    #region Parse filters
    If ($Filter) {
        $message = ("{0}: Checking `$Filter for unsupported keys, and removing them." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $filterClone = $Filter.Clone()
        Foreach ($key in $filterClone.GetEnumerator()) {
            If ($key.Name -notin @("id", "name", "organization_id", "configuration_type_id", "configuration_status_id", "contact_id", "serial_number", "asset_tag", "psa_id", "psa_integration_type", "rmm_id", "rmm_integration_type", "archived" )) {
                $message = ("{0}: The key, {1} is not in the allowed list, removing it from the filter." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $key.Name)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                $Filter.Remove($key.Key)
            } ElseIf ($key.Name -notmatch 'filter\[.*\]') {
                $Filter."filter[$($key.Name)]" = $($key.value)
                $Filter.Remove($key.Key)
            }
        }

        $message = ("{0}: Using filter:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($Filter | Out-String))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
    }
    #endregion Parse filters

    #region Main
    If ($Filter) {
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
                    $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($Filter + $queryBody | Out-String), "$UriBase/flexible_assets")
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations" -Body $apiFilter -ErrorAction Stop

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
                                    "page[size]"                     = $PageSize
                                    "page[number]"                   = $page
                                    "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
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
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            Foreach ($item in $response.data) {
                $retrievedInstanceCollection.Add($item)
            }

            $page++
        }
        Until ($response.meta.'next-page' -eq $null)

        If ($retrievedInstanceCollection.id.Count -gt $response.meta.'total-count') {
            $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.id.Count, $response.meta.'total-count')
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        If ($retrievedInstanceCollection.id) {
            $message = ("{0}: Returning {1} Configuration instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.id.Count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return $retrievedInstanceCollection
        } Else {
            $message = ("{0}: No instances retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Return "Error"
        }
    }
    Else {
        If ($ComputerName -eq "All") {
            $message = ("{0}: Getting all devices configurations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=1" -ErrorAction Stop

                    $stopLoop = $True

                    $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
                } Catch {
                    If ($_.Exception.Message -match 429) {
                        If ($429Count -lt 9) {
                            $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            $429Count++

                            Start-Sleep -Seconds 60
                        } Else {
                            $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                            Return "Error"
                        }
                    } Else {
                        If (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                            $loopCount++
                        } Else {
                            $message = ("{0}: Unexpected error getting device configuration assets. To prevent errors, {1} will exit. Error details, if present:`r`n`t
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
                    } Catch {
                        If ($_.Exception.Message -match 429) {
                            If ($429Count -lt 9) {
                                $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                                $429Count++

                                Start-Sleep -Seconds 60
                            } Else {
                                $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                                Return "Error"
                            }
                        } Else {
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
                                    } Else {
                                        $loopCount = 1
                                        $PageSize = $PageSize / 2
                                        $page = [math]::Round(($retrievedInstanceCollection.Count / $PageSize) + 1)
                                        $queryBody = @{
                                            "page[size]"                     = $PageSize
                                            "page[number]"                   = $page
                                            "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
                                        }
                                    }
                                }
                            } Else {
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
            While ($retrievedInstanceCollection.data.Count -lt $instanceTotalCount.meta.'total-count')

            If ($retrievedInstanceCollection.data.Count -gt $instanceTotalCount.meta.'total-count') {
                $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.data.Count, $instanceTotalCount.meta.'total-count')
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }

            $message = ("{0}: Found {1} device configurations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return $retrievedInstanceCollection.data
        } ElseIf ($OrganizationId -ne $null) {
            $message = ("{0}: Getting devices for customer with ID {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrganizationId)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=1&filter[organization-id]=$OrganizationId" -ErrorAction Stop

                    $stopLoop = $True

                    $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
                } Catch {
                    If ($_.Exception.Message -match 429) {
                        If ($429Count -lt 9) {
                            $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            $429Count++

                            Start-Sleep -Seconds 60
                        } Else {
                            $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                            Return "Error"
                        }
                    } Else {
                        If (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                            $loopCount++
                        } Else {
                            $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                            Return "Error"
                        }
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
                    "filter[organization-id]" = $OrganizationId
                }

                $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instanceTotalCount.meta.'total-count'))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Do {
                    Try {
                        $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($queryBody | Out-String), "$UriBase/flexible_assets")
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

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
                                        "page[size]"                     = $PageSize
                                        "page[number]"                   = $page
                                        "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
                                    }
                                }
                            }
                        } Else {
                            $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

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
            While (($retrievedInstanceCollection.data.Count -lt $instanceTotalCount.meta.'total-count') -and ($onlyOneInstance -eq $false))

            If ($ComputerName) {
                $message = ("{0}: Returning devices matching {1} at {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName, $OrganizationId)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Return ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -match $ComputerName })
            } Else {
                $message = ("{0}: Returning devices at {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrganizationId)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Return $retrievedInstanceCollection.data
            }
        } ElseIf ($ComputerName -ne $null) {
            $message = ("{0}: Getting all devices configurations with the hostname matching {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $stopLoop = $false
            Do {
                Try {
                    $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=1" -ErrorAction Stop

                    $stopLoop = $True

                    $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
                } Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    } ElseIf (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    } Else {
                        $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

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
                                        "page[size]"                     = $PageSize
                                        "page[number]"                   = $page
                                        "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
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
                            $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

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
            While (($retrievedInstanceCollection.data.Count -lt $instanceTotalCount.meta.'total-count') -and ($onlyOneInstance -eq $false))

            If ($retrievedInstanceCollection.data.Count -gt $instanceTotalCount.meta.'total-count') {
                $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.data.Count, $instanceTotalCount.meta.'total-count')
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }

            $message = ("{0}: Found {1} device configurations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $message = ("{0}: Returning devices matching {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -match $ComputerName })
        } Else {
            $message = ("{0}: No computer name or customer ID supplied. Please supply a value for one or both parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }
    }
    #endregion Main
} #1.0.0.22
<# as of 20 june 2022, this doesn't work yet.
later on 20 june 2022, the bits are here. need to add looping for retrieval and support access token being provided by user
#>
Function Get-ItGlueDocumentFolder {
    <#
        .DESCRIPTION
            
        .NOTES
            V2022.03.02.0
                - Initial release.
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER OrganizationId
            Desired customer's ITGlue organization ID.
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
            PS C:\> Get-ItGlueDeviceConfig -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -ComputerName All
            ## need to update
            In this example, the cmdlet will get all ITGlue device configurations, using the provided ITGlue API key.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [Alias("ItGlueCustomerId", "CustomerId")]
        [int64]$OrganizationId,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

        [Alias("ItGlueUriBase")]
        [string]$UriBase = "https://synoptek.itglue.com",

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

            $UriBase = 'https://itg-api-prod-lb-us-west-2.itglue.com/api/organizations/3345245/relationships/document_folders/2217402'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
            $header = @{ 'content-type' = 'application/vnd.api+json'; 'accept' = 'application/json, text/plain'; 'authorization' = "Bearer $accessToken" }
        }
    }
    #endregion Setup

    $response = Invoke-RestMethod -Method GET -UseBasicParsing -Uri "https://itg-api-prod-api-lb-us-west-2.itglue.com/api/organizations/$orgId/relationships/document_folders/$folderId" `
        -Headers @{
        "Authorization" = "Bearer $accessToken"
        'Content-Type'  = 'application/vnd.api+json'
        'Accept'        = 'application/json, text/plain'
    }

    #region Parse filters
    If ($Filter) {
        $message = ("{0}: Checking `$Filter for unsupported keys, and removing them." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $filterClone = $Filter.Clone()
        Foreach ($key in $filterClone.GetEnumerator()) {
            If ($key.Name -notin @("id", "name", "organization_id", "configuration_type_id", "configuration_status_id", "contact_id", "serial_number", "asset_tag", "psa_id", "psa_integration_type", "rmm_id", "rmm_integration_type", "archived" )) {
                $message = ("{0}: The key, {1} is not in the allowed list, removing it from the filter." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $key.Name)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                $Filter.Remove($key.Key)
            } ElseIf ($key.Name -notmatch 'filter\[.*\]') {
                $Filter."filter[$($key.Name)]" = $($key.value)
                $Filter.Remove($key.Key)
            }
        }

        $message = ("{0}: Using filter:`r`n{1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($Filter | Out-String))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
    }
    #endregion Parse filters

    #region Main
    If ($Filter) {
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
                    $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($Filter + $queryBody | Out-String), "$UriBase/flexible_assets")
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations" -Body $apiFilter -ErrorAction Stop
                    $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase"-ErrorAction Stop

                    $body = @{
                        'type' = 'configurations'
                        'attributes' = @{
                            "location-id" = 25505090
                        }
                    } | ConvertTo-Json
                    $response = Invoke-RestMethod -Method PATCH -Headers $header -Uri "https://synoptek.itglue.com/5577711/configurations/45819392" -Body $body -ErrorAction Stop
                    $response = Invoke-RestMethod -Method PATCH -Headers $header -Uri "https://synoptek.itglue.com/configurations/45819392" -Body $body -ErrorAction Stop
                    $response = Invoke-RestMethod -Method PATCH -Headers $header -Uri "https://synoptek.itglue.com/organizations/5577711/relationships/configurations/45819392" -Body $body -ErrorAction Stop

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
                                    "page[size]"                     = $PageSize
                                    "page[number]"                   = $page
                                    "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
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
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            Foreach ($item in $response.data) {
                $retrievedInstanceCollection.Add($item)
            }

            $page++
        }
        Until ($response.meta.'next-page' -eq $null)

        If ($retrievedInstanceCollection.id.Count -gt $response.meta.'total-count') {
            $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.id.Count, $response.meta.'total-count')
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        If ($retrievedInstanceCollection.id) {
            $message = ("{0}: Returning {1} Configuration instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.id.Count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return $retrievedInstanceCollection
        } Else {
            $message = ("{0}: No instances retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

            Return "Error"
        }
    }
    Else {
        If ($ComputerName -eq "All") {
            $message = ("{0}: Getting all devices configurations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=1" -ErrorAction Stop

                    $stopLoop = $True

                    $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
                } Catch {
                    If ($_.Exception.Message -match 429) {
                        If ($429Count -lt 9) {
                            $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            $429Count++

                            Start-Sleep -Seconds 60
                        } Else {
                            $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                            Return "Error"
                        }
                    } Else {
                        If (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                            $loopCount++
                        } Else {
                            $message = ("{0}: Unexpected error getting device configuration assets. To prevent errors, {1} will exit. Error details, if present:`r`n`t
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
                    } Catch {
                        If ($_.Exception.Message -match 429) {
                            If ($429Count -lt 9) {
                                $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                                $429Count++

                                Start-Sleep -Seconds 60
                            } Else {
                                $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                                Return "Error"
                            }
                        } Else {
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
                                    } Else {
                                        $loopCount = 1
                                        $PageSize = $PageSize / 2
                                        $page = [math]::Round(($retrievedInstanceCollection.Count / $PageSize) + 1)
                                        $queryBody = @{
                                            "page[size]"                     = $PageSize
                                            "page[number]"                   = $page
                                            "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
                                        }
                                    }
                                }
                            } Else {
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
            While ($retrievedInstanceCollection.data.Count -lt $instanceTotalCount.meta.'total-count')

            If ($retrievedInstanceCollection.data.Count -gt $instanceTotalCount.meta.'total-count') {
                $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.data.Count, $instanceTotalCount.meta.'total-count')
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }

            $message = ("{0}: Found {1} device configurations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return $retrievedInstanceCollection.data
        } ElseIf ($OrganizationId -ne $null) {
            $message = ("{0}: Getting devices for customer with ID {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrganizationId)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=1&filter[organization-id]=$OrganizationId" -ErrorAction Stop

                    $stopLoop = $True

                    $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
                } Catch {
                    If ($_.Exception.Message -match 429) {
                        If ($429Count -lt 9) {
                            $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            $429Count++

                            Start-Sleep -Seconds 60
                        } Else {
                            $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                            Return "Error"
                        }
                    } Else {
                        If (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                            $loopCount++
                        } Else {
                            $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                            Return "Error"
                        }
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
                    "filter[organization-id]" = $OrganizationId
                }

                $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instanceTotalCount.meta.'total-count'))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Do {
                    Try {
                        $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($queryBody | Out-String), "$UriBase/flexible_assets")
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

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
                                        "page[size]"                     = $PageSize
                                        "page[number]"                   = $page
                                        "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
                                    }
                                }
                            }
                        } Else {
                            $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

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
            While (($retrievedInstanceCollection.data.Count -lt $instanceTotalCount.meta.'total-count') -and ($onlyOneInstance -eq $false))

            If ($ComputerName) {
                $message = ("{0}: Returning devices matching {1} at {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName, $OrganizationId)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Return ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -match $ComputerName })
            } Else {
                $message = ("{0}: Returning devices at {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrganizationId)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Return $retrievedInstanceCollection.data
            }
        } ElseIf ($ComputerName -ne $null) {
            $message = ("{0}: Getting all devices configurations with the hostname matching {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $stopLoop = $false
            Do {
                Try {
                    $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=1" -ErrorAction Stop

                    $stopLoop = $True

                    $message = ("{0}: {1} identified {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
                } Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    } ElseIf (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    } Else {
                        $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

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
                                        "page[size]"                     = $PageSize
                                        "page[number]"                   = $page
                                        "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
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
                            $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

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
            While (($retrievedInstanceCollection.data.Count -lt $instanceTotalCount.meta.'total-count') -and ($onlyOneInstance -eq $false))

            If ($retrievedInstanceCollection.data.Count -gt $instanceTotalCount.meta.'total-count') {
                $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.data.Count, $instanceTotalCount.meta.'total-count')
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }

            $message = ("{0}: Found {1} device configurations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $message = ("{0}: Returning devices matching {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ComputerName)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -match $ComputerName })
        } Else {
            $message = ("{0}: No computer name or customer ID supplied. Please supply a value for one or both parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }
    }
    #endregion Main
} #1.0.0.22
Function Get-ItGlueFlexibleAssetField {
    <#
        .DESCRIPTION
            Returns ITGlue flexible asset type properties.
        .NOTES
            V1.0.0.0 date: 19 March 2021
                - Initial release
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
        .PARAMETER PageSize
            Page size when requesting ITGlue resources via the API. Note that retrieving flexible asset instances is computationally expensive, which may cause a timeout. When that happens, drop the page size down (a lot).
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-Get-ItGlueFlexibleAssetField -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Id 123456 Verbose

            In this example, the cmdlet will return propreties of the flexible asset type 123456, using the provided ITGlue API key. Verbose logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-Get-ItGlueFlexibleAssetField -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -LogPath C:\temp\log.txt

            In this example, the cmdlet will return propreties of flexible asset types, using the provided ITGlue API key. Limited logging output is sent to the host and C:\temp\log.txt.
        .EXAMPLE
            PS C:\> Get-Get-ItGlueFlexibleAssetField -Id 123456 -Credential (Get-Credential) -LogPath C:\Temp\log.txt

            In this example, the cmdlet will return properties of the flexible asset type 123456, using the provided ITGlue user credentials. Limited logging output is sent to the host and C:\temp\log.txt.
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
        $Id,

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
    $flexibleAssetTypesCollection = [System.Collections.Generic.List[PSObject]]::New()
    $stopLoop = $false
    $loopCount = 1
    $429Count = 0

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
                Verbose = $false
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $false
                LogPath = $LogPath
            }
        }
        Else {
            $commandParams = @{
                Verbose = $false
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
    #endregion Setup

    #region Main
    If ($Id) {
        Try {
            $type = (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/flexible_asset_types/$Id" -ErrorAction Stop).data
        }
        Catch {
            If ($_.Exception.Message -match 429) {
                If ($429Count -lt 9) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    $429Count++

                    Start-Sleep -Seconds 60
                } Else {
                    $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
            } Else {
                If (($loopCount -lt 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                } Else {
                    $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                    Return "Error"
                }
            }
        }

        If (-NOT($type)) {
            $message = ("{0}: Unable to identify flexible asset type properties for flexible asset type with ID {1}. To prevent errors, {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id, $MyInvocation.MyCommand)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }
        Try {
            $message = ("{0}: Getting fields for {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $fields = (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/flexible_asset_types/$Id/relationships/flexible_asset_fields" -ErrorAction Stop).data.attributes

            [PSCustomObject]@{
                typeName        = $type.attributes.name
                typeDescription = $type.attributes.description
                typeCreatedAt   = $type.attributes.'created-at'
                typeUpdatedAt   = $type.attributes.'updated-at'
                typeIcon        = $type.attributes.icon
                typeEnabled     = $type.attributes.enabled
                typeFields      = @(
                    $fields
                )
            }

            $stopLoop = $True
        } Catch {
            If ($_.Exception.Message -match 429) {
                If ($429Count -lt 9) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    $429Count++

                    Start-Sleep -Seconds 60
                } Else {
                    $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
            } Else {
                If (($loopCount -lt 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                } Else {
                    $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                    Return "Error"
                }
            }
        }
    }
    Else {
        $message = ("{0}: Attempting to determine how many asset types there are to be retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                $message = ("{0}: Sending the following`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ((@{"filter[flexible_asset_type_id]" = "$FlexibleAssetId" }) | Out-String), "$UriBase/flexible_assets?page[size]=$PageSize")
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                $instanceTotalCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/flexible_asset_types?page[size]=1" -ErrorAction Stop

                $stopLoop = $True

                $message = ("{0}: {1} identified {2} asset types." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $($instanceTotalCount.meta.'total-count'))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
            } Catch {
                If ($_.Exception.Message -match 429) {
                    If ($429Count -lt 9) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        $429Count++

                        Start-Sleep -Seconds 60
                    } Else {
                        $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                    }
                } Else {
                    If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 4, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    } Else {
                        $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }
                }
            }
        }
        While ($stopLoop -eq $false)

        If (-NOT($($instanceTotalCount.meta.'total-count') -gt 0)) {
            $message = ("{0}: Zero asset types were identified. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
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
            }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $flexibleAssetTypesCollection.Count, $($instanceTotalCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($queryBody | Out-String), "$UriBase/flexible_assets")
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/flexible_asset_types" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $flexibleAssetTypesCollection.Add($_) }

                    $stopLoop = $True
                } Catch {
                    If ($_.Exception.Message -match 429) {
                        If ($429Count -lt 9) {
                            $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                            $429Count++

                            Start-Sleep -Seconds 60
                        } Else {
                            $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                            Return "Error"
                        }
                    } Else {
                        If (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                            $loopCount++

                            If ($loopCount -eq 6) {
                                $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                                If ($PageSize -eq 1) {
                                    $message = ("{0}: Cannot lower the page count any futher, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $_.Exception.Message)
                                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                                    # Sometimes, the function returns instance values and the string, "error". Doing this should prevent that.
                                    $flexibleAssetTypesCollection = "Error"

                                    Return "Error"
                                } Else {
                                    $loopCount = 1
                                    $PageSize = $PageSize / 2
                                    $page = [math]::Round(($flexibleAssetTypesCollection.count / $PageSize) + 1)
                                    $queryBody = @{
                                        "page[size]"                     = $PageSize
                                        "page[number]"                   = $page
                                        "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
                                    }
                                }
                            }
                        } Else {
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
        While ($flexibleAssetTypesCollection.Count -lt $instanceTotalCount.meta.'total-count')

        $allData = Foreach ($type in $flexibleAssetTypeCollection.data) {
            $stopLoop = $False
            Try {
                $message = ("{0}: Getting fields for {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $type.attributes.name)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                $fields = (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/flexible_asset_types/$($type.id)/relationships/flexible_asset_fields" -ErrorAction Stop).data.attributes

                [PSCustomObject]@{
                    typeName        = $type.attributes.name
                    typeDescription = $type.attributes.description
                    typeCreatedAt   = $type.attributes.'created-at'
                    typeUpdatedAt   = $type.attributes.'updated-at'
                    typeIcon        = $type.attributes.icon
                    typeEnabled     = $type.attributes.enabled
                    typeFields      = @(
                        $fields
                    )
                }

                $stopLoop = $True
            } Catch {
                If ($_.Exception.Message -match 429) {
                    If ($429Count -lt 9) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        $429Count++

                        Start-Sleep -Seconds 60
                    } Else {
                        $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                    }
                } Else {
                    If (($loopCount -lt 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    } Else {
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
                    }
                }
            }
        }

        If ($allData) {
            $message = ("{0}: Returning fields for {1} flexible asset types." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $allData.Count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return $allData
        }
        Else {
            Return "Error"
        }
    }
    #endregion Main
} #1.0.0.0
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
    #endregion Setup

    #region Main
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
                If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 4, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                }
                Else {
                    $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                    Return "Error"
                }
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
                    If (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++

                        If ($loopCount -eq 6) {
                            $message = ("{0}: Re-try count reached, resetting the query parameters." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

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
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

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
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

        Return "Error"
    }
    Else {
        Return $retrievedInstanceCollection
    }
    #endregion Main
} #1.0.0.21
Function Get-ItGlueGroup {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or more groups.
        .NOTES
            V1.0.0.0 date: 12 July 2022
            V1.0.0.1 date: 13 July 2022
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
            PS C:\> Get-ItGlueGroup -Filters @{ name = 'group 1' } -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -IncludeUsers -LogPath C:\Temp\log.txt

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

        [Switch]$IncludeUsers,

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
    $userFilter = ''

    If ($IncludeUsers) {
        $userFilter = '?include=users'
    }
    #endregion Initialize variables

    # Setup parameters for calling Get-ItGlueJsonWebToken.
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
        }
    }

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

                        $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase$resourcePath$userFilter" -Body $apiFilter -ErrorAction Stop

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
            V1.0.0.9 date: 8 July 2020
        .PARAMETER Credential
            ITGlue credential object for the desired local account.
        .PARAMETER ItGlueUriBase
            Base URL for the ITGlue customer.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
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

        [boolean]$BlockStdErr = $false,

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
        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $true } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $true } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $true }

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
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $true } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $true } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $true }

        Return "Error"
    }
    #endregion get access token

    Return $accessToken
} #1.0.0.9
Function Get-ItGlueLocation {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or locations.
        .NOTES
            V1.0.0.0 date: 16 July 2020
            V1.0.0.1 date: 7 August 2020
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

        [Alias("ItGlueCustomerId", "OrganizationId")]
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
                Verbose        = $false
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $false
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
} #1.0.0.1
Function Get-ItGlueManufacturer {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or manufacturers.
        .NOTES
            V1.0.0.0 date: 16 July 2020
            V1.0.0.1 date: 7 August 2020
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER Name
            Desired manufacturer's name.
        .PARAMETER Id
            Desired manufacturer's ID.
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
            PS C:\> Get-ItGlueManufacturer -ItGlueApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will retrieve all instances of the manufacturer asset type. Limited logging output is sent only to the session host.
        .EXAMPLE
            PS C:\> Get-ItGlueManufacturer -ItGlueApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Name Cisco -Verbose

            In this example, the cmdlet will retrieve the Cisco instance of the manufacturer asset type. Verbose logging output is sent only to the session host.
        .EXAMPLE
            PS C:\> Get-ItGlueManufacturer -ItGlueApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Id 111111 -Verbose -LogPath C:\Temp\log.txt

            In this example, the cmdlet will retrieve the instance of the manufacturer asset type with ID 111111. Verbose logging output is sent to the session host and C:\Temp\log.txt
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [string]$Name,

        [int64]$Id,

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
                Verbose        = $false
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $false
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
    #endregion Setup

    #region Main
    If ($Name -and $Id) {
        $message = ("{0}: Both -Name and -Id were provided. Please choose one and re-submit the request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

        Return "Error"
    }
    ElseIf (-NOT($Name) -and -NOT($Id)) {
        $message = ("{0}: No name or ID supplied, defaulting to retrieve all manufacturers." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message }

        Do {
            Try {
                $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/manufacturers?page[size]=1" -ErrorAction Stop

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
                    If (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out."))) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
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

            Return "Error"
        }

        $page = 1
        Do {
            $loopCount = 1
            $stopLoop = $False
            $queryBody = @{
                "page[size]"   = $PageSize
                "page[number]" = $page
            }

            $message = ("{0}: Body: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), , ($queryBody | Out-String), "$UriBase/manufacturers")
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/manufacturers" -Body $queryBody -ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        If (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out."))) {
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

        $message = ("{0}: Found {1} manufacturers, filtering for {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $Name)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return $retrievedInstanceCollection
    }
    ElseIf ($Name) {
        $message = ("{0}: Getting information about {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Name)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/manufacturers?page[size]=1" -ErrorAction Stop

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
                    If (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out."))) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
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

            Return "Error"
        }

        $page = 1
        Do {
            $loopCount = 1
            $stopLoop = $False
            $queryBody = @{
                "page[size]"   = $PageSize
                "page[number]" = $page
            }

            $message = ("{0}: Body: {1}`r`n`tUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($queryBody | Out-String), "$UriBase/manufacturers")
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            $message = ("{0}: Retrieved {1} of {2} instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/manufacturers" -Body $queryBody -ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If ($_.Exception.Message -match 429) {
                        $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        If (($loopCount -le 6) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out."))) {
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

        $message = ("{0}: Found {1} manufacturers, filtering for {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $Name)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return ($retrievedInstanceCollection | Where-Object { $_.attributes.'name' -eq $Name })
    }
    ElseIf ($Id) {
        $message = ("{0}: Getting information about manufacturer {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/manufacturers/$Id"-ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                $stopLoop = $True
            }
            Catch {
                If ($_.Exception.Message -match 429) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    Start-Sleep -Seconds 60
                }
                Else {
                    If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out."))) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    }
                    ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                        $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id, $MyInvocation.MyCommand)
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
} #1.0.0.1
Function Get-ItGlueModel {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or models.
        .NOTES
            V1.0.0.0 date: 16 July 2020
            V1.0.0.1 date: 7 August 2020
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER Name
            Desired manufacturer's name.
        .PARAMETER Id
            Desired manufacturer's ID.
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
            PS C:\> Get-ItGlueModel -ApiKey $ItGlueApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will retrieve all instances of the model asset type. Limited logging output is sent only to the session host.
        .EXAMPLE
            PS C:\> Get-ItGlueModel -UserCred (Get-Credential) -ModelId 111111 -Verbose

            In this example, the cmdlet will retrieve the instance of the manufacturer asset type with ID 111111. Verbose logging output is sent only to the session host.
        .EXAMPLE
            PS C:\> Get-ItGlueModel -ItGlueApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -ManufacturerId 111111 -Verbose -LogPath C:\Temp\log.txt

            In this example, the cmdlet will retrieve all model assets associated with the manufacturer with ID 111111. Verbose logging output is sent to the session host and C:\Temp\log.txt
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [int64]$ModelId,

        [int]$ManufacturerId,

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
                Verbose        = $false
                EventLogSource = $EventLogSource
            }
        }
        ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $commandParams = @{
                Verbose = $false
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
    #endregion Setup

    #region Main
    If ($ModelId -and $ManufacturerId) {
        $message = ("{0}: Both -ModelId and -ManufacturerId were provided. Please choose one and re-submit the request." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

        Return "Error"
    }
    If (-NOT($ModelId) -and -NOT($ManufacturerId)) {
        $message = ("{0}: No IDs supplied, defaulting to retrieve all models from all manufacturers." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $manufacturers = Get-ITGlueManufacturer -ApiKey $ApiKey @commandParams

        If (($manufacturers -eq "Error") -or ($manufacturers.count -lt 1)) {
            $message = ("{0}: There are {1} manufacturers. To prevent further errors, {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $manufacturers.count, $MyInvocation.MyCommand)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }
        Else {
            $message = ("{0}: There are {1} manufacturers." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $manufacturers.count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }
        }

        $i = 0
        $models = $manufacturers | Foreach-Object {
           # Start-Sleep -Seconds 2
            $i++

            $message = ("{0}: Calling command to get models associated with {1}. This is manufacturer {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $manufacturers.attributes.name, $i, $manufacturers.count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Get-ItGlueModel -ManufacturerId $_.id -ApiKey $ApiKey @commandParams
        }

        If (($models -eq "Error") -or ($models.Count -lt 1)) {
            $message = ("{0}: Error getting models. To prevent further errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }
        Else {
            $message = ("{0}: Returning {1} models." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $models.Count)
            If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

            Return $models
        }
    }
    ElseIf ($ManufacturerId) {
        $message = ("{0}: Getting information about models under the manufacturer with ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ManufacturerId)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/manufacturers/$ManufacturerId/relationships/models" -ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                $stopLoop = $True
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
                    If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    }
                    ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id, $MyInvocation.MyCommand)
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
    Else {
        $message = ("{0}: Getting information about model with ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $ModelId)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Do {
            Try {
                (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/models/$ModelId" -ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                $stopLoop = $True
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
                    If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                        $loopCount++
                    }
                    ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                        $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id, $MyInvocation.MyCommand)
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
} #1.0.0.1
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
            V1.0.0.14 date: 8 July 2020
            V1.0.0.15 date: 7 August 2020
            V1.0.0.16 date: 13 November 2020
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER OrganizationName
            Enter the name of the desired customer, or "All" to retrieve all organizations.
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
            PS C:\> Get-ItGlueOrganization -ItGlueApiKey ITG.XXXXXXXXXXXXX -OrganizationName All

            In this example, the cmdlet will get all of the organzations in the instance. Output is sent to the host session and event log.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -UserCred (Get-Credential) -ComputerName company1 -Verbose

            In this example, the cmdlet will get all of the organzations in the instance, with the name "company1". Verbose output is sent to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -UserCred (Get-Credential) -OrganizationId 123456 -BlockLogging -LogPath C:\Temp\log.txt

            In this example, the cmdlet will get the customer with ID 123456, using the provided ITGlue user credentials. Output will be written to the log file and host.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [ValidatePattern("^All$|^[a-z,A-Z,0-9]+")]
        [Alias("CustomerName")]
        [string]$OrganizationName,

        [Alias("ItGlueCustomerId", "CustomerId")]
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
    #endregion Setup

    #region Main
    If (-NOT(($OrganizationName) -or ($OrganizationId))) {
        $message = ("{0}: No customer name or ID supplied. Defaulting to retrieving all organizations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message }

        $OrganizationName = "All"
    }

    If ($OrganizationName -eq "All") {
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
                            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                            Return "Error"
                        }
                    }

                }
            }
            While ($stopLoop -eq $false)

            $page++
        }
        While ($retrievedInstanceCollection.data.Count -ne $instancePageCount.meta.'total-count')

        If ($retrievedInstanceCollection.data.Count -gt $instancePageCount.meta.'total-count') {
            $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.data.Count, $instancePageCount.meta.'total-count')
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        $message = ("{0}: Found {1} organizations." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.count)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return $retrievedInstanceCollection.data
    }
    ElseIf ($OrganizationName) {
        $message = ("{0}: Getting the org, {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrganizationName)
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
        While ($retrievedInstanceCollection.data.Count -lt $instancePageCount.meta.'total-count')

        If ($retrievedInstanceCollection.data.Count -gt $instancePageCount.meta.'total-count') {
            $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.data.Count, $instancePageCount.meta.'total-count')
            If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

            Return "Error"
        }

        $message = ("{0}: Found {1} organizations, filtering for {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.data.Count, $OrganizationName)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        Return ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -eq $OrganizationName })
    }
    ElseIf ($OrganizationId) {
        $message = ("{0}: Getting organization with ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrganizationId)
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $loopCount = 1
        $stopLoop = $false
        Do {
            Try {
                (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations/$OrganizationId" -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                $stopLoop = $True
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

        Return $retrievedInstanceCollection.data
    }
    #endregion Main
} #1.0.0.16
Function Get-ItGlueUser {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or more users.
        .NOTES
            V1.0.0.0 date: 12 July 2022
            V1.0.0.1 date: 12 July 2022
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ContactId
            Represents the ID of the desired contact instance.
        .PARAMETER Filters
            Represents a hashtable of supported API filters. If non-supported keys are included, the cmdlet will remove them before further processing. As of 16 November 2021, the following values are supported:

            id, name, email, role_name

            See https://api.itglue.com/developer/#accounts-users-index, for information regarding data types.
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
            PS C:\> Get-ItGlueUser Id 123 -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will get the user with ID 123, using the provided ITGlue API key. Limited logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueUser -Filter @{ id = 123 } -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will get the user with ID 123, using the provided ITGlue API key. Limited logging output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueUser -Filter @{ id = "123,890" } -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Verbose

            In this example, the cmdlet will get the users with ID 123 and 890, using the provided ITGlue API key. Verbose logging output is sent only to the host.
         .EXAMPLE
            PS C:\> Get-ItGlueUser -Filter @{ email = "user@domain.tld"; role_name = "Editor" } -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -LogPath C:\Temp\log.txt

            In this example, the cmdlet will get the user with username "user@domain.tld" and role "Editor", using the provided ITGlue API key. Limited logging output is sent to the host and C:\Temp\log.txt.
         .EXAMPLE
            PS C:\> Get-ItGlueUser -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -LogPath C:\Temp\log.txt -Verbose

            In this example, the cmdlet will get all users, using the provided ITGlue API key. Verbose logging output is sent to the host and C:\Temp\log.txt.
    #>
    [CmdletBinding(DefaultParameterSetName = 'AllUsers')]
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
    $resourcePath = '/users'
    #endregion Initialize variables

    # Setup parameters for calling Get-ItGlueJsonWebToken.
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
        }
    }

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
    Switch ($PsCmdlet.ParameterSetName) {
        { $_ -in ("HashtableFilter", "AllUsers") } {
            #region Parse filters
            If ($Filter) {
                $message = ("{0}: Checking `$Filter for unsupported keys, and removing them." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                $filterClone = $Filter.Clone()
                Foreach ($key in $filterClone.GetEnumerator()) {
                    If ($key.Name -notin @("id", "name", "email", "role_name")) {
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

            #region Get data
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
                        $message = ("{0}: Sending the following:`r`nBody: {1}`r`nUrl: {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($Filter + $queryBody | Out-String), "$UriBase/flexible_assets")
                        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                        $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase$resourcePath" -Body $apiFilter -ErrorAction Stop

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

                Foreach ($item in $response.data) {
                    $retrievedInstanceCollection.Add($item)
                }

                $page++
            }
            Until ($null -eq $response.meta.'next-page')
            #endregion Get data

            #region Return
            If ($retrievedInstanceCollection.id.Count -gt $response.meta.'total-count') {
                $message = ("{0}: Somehow, too many instances were retrieved. {1} retrieved {2} instances but ITGlue reports only {3} are available. To prevent errors, {1} will exit." -f `
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, $retrievedInstanceCollection.id.Count, $response.meta.'total-count')
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }

            If ($retrievedInstanceCollection.id) {
                $message = ("{0}: Returning {1} group instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $retrievedInstanceCollection.id.Count)
                If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                Return $retrievedInstanceCollection
            } Else {
                $message = ("{0}: No instances retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                Return "Error"
            }
            #endregion Return
        }
        { $_ -eq 'IdFilter' } {
            #region Get data
            $loopCount = 1
            $stopLoop = $False

            Do {
                Try {
                    $message = ("{0}: Sending the following:`r`n`tUrl: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$UriBase/flexible_assets")
                    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

                    $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase$resourcePath/$Id" -ErrorAction Stop

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
                                    "page[size]"                     = $PageSize
                                    "page[number]"                   = $page
                                    "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
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
            #endregion Get data

            #region Return
            If ($response.data.id) {
                $message = ("{0}: Successfully retrieved user properties, returning the user." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Info -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Info -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Info -Message $message -BlockStdErr $BlockStdErr }

                Return $response.data
            } Else {
                $message = ("{0}: No user returned for ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }
            #endregion Return
        }
    }
    #endregion Main
} #1.0.0.1
Function Out-ItGlueAsset {
    <#
        .DESCRIPTION
            Accepts a PSCustomObject, converts it to JSON and uploads it to ITGlue. Supports POST and PATCH HTTP methods.

            This cmdlet is used to update standard asset types (e.g. configurations, passwords, documents, contacts, etc.).
        .NOTES
            V1.0.0.0 date: 16 July 2020
            V1.0.0.1 date: 7 August 2020
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER Data
            Custom PSObject containing asset properties.
        .PARAMETER HttpMethod
            Used to dictate whether the cmdlet should use POST or PATCH when sending data to ITGlue.
        .PARAMETER AssetInstanceId
            When included, is used to update (PATCH) a specifc instance of an asset.
        .PARAMETER AssetType
            Represents the type of asset being created/updated.
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Out-ItGlueAsset -Data $uploadData -HttpMethod POST -AssetType configurations -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new configuration asset, using the provided ITGlue API key. The cmdlet will try uploading 5 times.
        .EXAMPLE
            PS C:\> Out-ItGlueAsset -Data $uploadData -HttpMethod PATCH -AssetType configurations -AssetInstanceId 123456 -UserCred (Get-Credential) -Verbose

            In this example, the cmdlet will convert the contents of $uploadData to JSON and update the asset with ID 123456, using the provided ITGlue user credentials. Verbose output is sent to the host.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$Data,

        [Parameter(Mandatory = $True)]
        [ValidateSet('POST', 'PATCH')]
        [string]$HttpMethod,

        [int64]$AssetInstanceId,

        [Parameter(Mandatory = $True)]
        [ValidateSet('configurations', 'contacts')]
        [string]$AssetType,

        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

        [string]$ItGlueUriBase = "https://api.itglue.com",

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    #region Setup
    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # We are patching, but don't have a asset instance to patch, request the ID.
    If (($HttpMethod -eq 'PATCH') -and (-NOT($AssetInstanceId))) {
        $AssetInstanceId = Read-Host -Message "Enter an asset instance ID"
    }

    # Initialize variables.
    $loopCount = 0
    $429Count = 0
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
        $message = ("{0}: Preparing URL {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$ItGlueUriBase/$AssetType/$AssetInstanceId")
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $uploadUrl = "$ItGlueUriBase/$AssetType/$AssetInstanceId"
    }
    Else {
        $message = ("{0}: Preparing URL {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$ItGlueUriBase/$AssetType")
        If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

        $uploadUrl = "$ItGlueUriBase/$AssetType"
    }
    #endregion Setup

    #region Main
    $message = ("{0}: Attempting to upload data to ITGlue (method: {1})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $HttpMethod)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $HttpMethod -Headers $header -Uri $uploadUrl -Body ($Data | ConvertTo-Json -Depth 10) -ErrorAction Stop

            $stopLoop = $True
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
            If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                $loopCount++
            }
            ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $AssetInstanceId, $MyInvocation.MyCommand)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }
            Else {
                $message = ("{0}: Unexpected error uploading to ITGlue. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                Error title: {2}`r`n`t
                Error detail is: {3}`r`n`t
                PowerShell returned: {4}" -f `
                        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)
    #endregion Main

    $response
} #1.0.0.1
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
            V1.0.0.18 date: 10 July 2020
            V1.0.0.19 date: 7 August 2020
            V1.0.0.20 date: 9 May 2021
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
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod POST -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force)

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new flexible asset, using the provided ITGlue API key. The cmdlet will try uploading 5 times.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod POST -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -MaxLoopCount 10

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

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    #region Setup
    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    # We are patching, but don't have a flexible asset instance to patch, request the ID.
    If (($HttpMethod -eq 'PATCH') -and (-NOT($FlexibleAssetInstanceId))) {
        $FlexibleAssetInstanceId = Read-Host -Message "Enter a flexible asset instance ID"
    }

    # Initialize variables.
    $loopCount = 0
    $429Count = 0
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
    #endregion Setup

    #region Main
    $message = ("{0}: Attempting to upload data to ITGlue (method: {1})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $HttpMethod)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $HttpMethod -Headers $header -Uri $uploadUrl -Body ($Data | ConvertTo-Json -Depth 10) -ErrorAction Stop

            $stopLoop = $True
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
                If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                }
                ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $FlexibleAssetInstanceId, $MyInvocation.MyCommand)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                    Return "Error"
                }
                Else {
                    If (($_.ErrorDetails.message) -and ($_.ErrorDetails.message -match "Invalid JSON format")) {
                        $message = ("{0}: ITGlue reported invalid JSON. The provided value was: {1}" -f ($Data | ConvertTo-Json -Depth 10))
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"
                    }
                    Else {
                        $message = ("{0}: Unexpected error uploading to ITGlue. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                            Error title: {2}`r`n`t
                            Error detail is: {3}`r`t`n
                            PowerShell returned: {4}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, ((($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail) | Out-String), $_.Exception.Message)
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message }

                        Return "Error"

                    }
                }
            }
        }
    }
    While ($stopLoop -eq $false)
    #endregion Main

    $response
} #1.0.0.20
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
            V1.0.0.4 date: 15 June 2020
            V1.0.0.5 date: 30 June 2020
            V1.0.0.6 date: 8 April 2021
            V1.0.0.7 date: 10 September 2021
            V1.0.0.8 date: 20 September 2021
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
        .PARAMETER BlockStdErr
            When set to $True, the cmdlet will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
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
        [string]$MessageType,

        [boolean]$BlockStdErr
    )

    # Initialize variables.
    $elevatedSession = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    If ($PsCmdlet.ParameterSetName -eq "EventLog") {
        If ([System.Diagnostics.EventLog]::SourceExists("$EventLogSource")) {
            # The event source does not exists, nothing else to do.

            $logType = "EventLog"
        } ElseIf (-NOT ([System.Diagnostics.EventLog]::SourceExists("$EventLogSource")) -and $elevatedSession) {
            # The event source does not exist, but the session is elevated, so create it.
            Try {
                New-EventLog -LogName Application -Source $EventLogSource -ErrorAction Stop

                $logType = "EventLog"
            } Catch {
                Write-Error ("[ERROR] {0}: Unable to create the event source ({1}). No logging will be done." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $EventLogSource)

                $logType = "SessionOnly"
            }
        } ElseIf (-NOT $elevatedSession) {
            # The event source does not exist, and the session is not elevated.
            Write-Error ("[ERROR] {0}: The event source ({1}) does not exist and the command was not run in an elevated session, unable to create the event source. No logging will be done." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $EventLogSource)

            $logType = "SessionOnly"
        }
    } ElseIf ($PsCmdlet.ParameterSetName -eq "File") {
        # Check if we have rights to the path in $LogPath.
        Try {
            [System.Io.File]::OpenWrite($LogPath).Close()
        } Catch {
            Write-Error ("[ERROR] {0}: Unable to write to the log file path ({1}). No logging will be done." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $LogPath)

            $logType = "SessionOnly"
        }

        $logType = "LogFile"
    } Else {
        $logType = "SessionOnly"
    }

    Switch ($logType) {
        "SessionOnly" {
            Switch ($MessageType) {
                "Info" { Write-Host "[INFO] $Message" }
                "Warning" { Write-Warning "[WARNING] $Message" }
                "Error" { If ($BlockStdErr) { Write-Host "[ERROR] $Message" -ForegroundColor Red } Else { Write-Error "[ERROR] $Message" } }
                "Verbose" { Write-Verbose "[VERBOSE] $Message" -Verbose }
                "First" { Write-Verbose "[INFO] $Message" -Verbose }
            }
        }
        "EventLog" {
            Switch ($MessageType) {
                "Info" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message "[INFO] $Message" -EventId 5417; Write-Host "[INFO] $Message" }
                "Warning" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message "[WARNING] $Message" -EventId 5417; Write-Warning "[WARNING] $Message" }
                "Error" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message "[ERROR] $Message" -EventId 5417; If ($BlockStdErr) { Write-Host "[ERROR] $Message" -ForegroundColor Red } Else { Write-Error "[ERROR] $Message" } }
                "Verbose" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message "[VERBOSE] $Message" -EventId 5417; Write-Verbose "[VERBOSE] $Message" -Verbose }
                "First" { Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message "[INFO] $Message" -EventId 5417; Write-Verbose "[INFO] $Message" -Verbose }
            }
            If ($BlockStdErr) {

            }
        }
        "LogFile" {
            Switch ($MessageType) {
                "Info" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]"[INFO] $Message", [Text.Encoding]::UTF8); Write-Host "[INFO] $Message" }
                "Warning" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]"[WARNING] $Message", [Text.Encoding]::UTF8); Write-Warning "[WARNING] $Message" }
                "Error" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]"[ERROR] $Message", [Text.Encoding]::UTF8); If ($BlockStdErr) { Write-Host "[ERROR] $Message" -ForegroundColor Red } Else { Write-Error "[ERROR] $Message" } }
                "Verbose" { [System.IO.File]::AppendAllLines([string]$LogPath, [string[]]"[VERBOSE] $Message", [Text.Encoding]::UTF8); Write-Verbose "[VERBOSE] $Message" -Verbose }
                "First" { [System.IO.File]::WriteAllLines($LogPath, "[INFO] $Message", [Text.Encoding]::UTF8); Write-Verbose "[INFO] $Message" -Verbose }
            }
        }
    }
} #1.0.0.8
Function Remove-ItGlueDeviceConfig {
    <#
        .DESCRIPTION
            Accept a configuration ID and delete it from ITGlue.
        .NOTES
            V1.0.0.0 date: 12 August 2019
                - Initial release.
            V1.0.0.1 date: 11 December 2019
            V1.0.0.2 date: 18 May 2020
            V1.0.0.3 date: 8 July 2020
            V1.0.0.4 date: 7 August 2020
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
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Remove-ItGlueFlexibleAssetInstance -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Id 123456

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
    $stopLoop = $false
    $httpVerb = 'DELETE'
    $429Count = 0

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
    #endregion Setup

    #region Main
    $message = ("{0}: Attempting to delete the device configuration with ID: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $httpVerb -Headers $header -Uri "$UriBase/configurations" -Body ($data | ConvertTo-Json) -ErrorAction Stop

            $stopLoop = $True
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
                If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                }
                ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    $message = ("{0}: The request for {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id, $MyInvocation.MyCommand)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                    Return "Error"
                }
                Else {
                    $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. Error details, if present:`r`n`t
                Error title: {2}`r`n`t
                Error detail is: {3}`r`n`t
                PowerShell returned: {4}" -f `
                        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                    Return "Error"
                }
            }
        }
    }
    While ($stopLoop -eq $false)
    #endregion Main

    Return $response
} #1.0.0.4
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
            V1.0.0.15 date: 8 July 2020
            V1.0.0.16 date: 7 August 2020
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
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Remove-ItGlueFlexibleAssetInstance -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Id 123456 -LogPath C:\Temp\log.txt

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
    $stopLoop = $false
    $httpVerb = 'DELETE'
    $429Count = 0

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
    #endregion Setup

    #region Main
    $message = ("{0}: Attempting to delete the flexible asset with instance: {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id)
    If ($PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue') { If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Verbose -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Verbose -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Verbose -Message $message } }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $httpVerb -Headers $header -Uri "$UriBase/flexible_assets/$Id" -ErrorAction Stop

            $stopLoop = $True
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
                If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Warning -Message $message } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Warning -Message $message } Else { Out-PsLogging -ScreenOnly -MessageType Warning -Message $message }

                    $loopCount++
                }
                ElseIf (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    $message = ("{0}: The request to delete flexible asset {1} timed out. {2} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id, $MyInvocation.MyCommand)
                    If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                    Return "Error"
                }
                ElseIf ($_.Exception.Message -eq 'The underlying connection was closed: A connection that was expected to be kept alive was closed by the server') {
                    $connectionClosedCount++

                    If ($connectionClosedCount -le 2) {
                        $message = ("{0}: It appears that ITGlue closed the connection. Waiting 60 seconds, then trying again (up to two times)." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        $message = ("{0}: ITGlue closed the connection too many times." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                        If ($EventLogSource -and (-NOT $LogPath)) { Out-PsLogging -EventLogSource $EventLogSource -MessageType Error -Message $message -BlockStdErr $BlockStdErr } ElseIf ($LogPath -and (-NOT $EventLogSource)) { Out-PsLogging -LogPath $LogPath -MessageType Error -Message $message -BlockStdErr $BlockStdErr } Else { Out-PsLogging -ScreenOnly -MessageType Error -Message $message -BlockStdErr $BlockStdErr }

                        Return "Error"
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
    #endregion Main

    Return $response
} #1.0.0.16
Export-ModuleMember -Alias * -Function *
