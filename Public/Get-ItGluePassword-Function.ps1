Function Get-ItGluePassword {
    <#
        .DESCRIPTION
            Gets one or more ITGlue Passwords. By default the secret part of the Password object is not returned.
        .NOTES
            V2023.01.13.0
            V2023.01.23.0
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER Id
            Id of the desired Password.
        .PARAMETER Filter
            Optional Password filter. valid filters include: id, name, organization_id, password_category_id, url, cached_resource_name, archived. See https://api.itglue.com/developer/#passwords-index, for more information.
        .PARAMETER All
            When included, the cmdlet will return all active Passwords.
        .PARAMETER IncludePassword
            When included, the cmdlet will return the secret part of the Password, in the response.
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
            PS C:\> Get-ItGluePassword -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Id 123456 -Verbose

            In this example, the cmdlet will get return properties of the Password with ID 123456, using the provided ITGlue API key. The "password" of the Password will not be retrieved. Verbose logging output is sent to the host only.
                .EXAMPLE
            PS C:\> Get-ItGluePassword -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Id 123456 -IncludePassword -Verbose

            In this example, the cmdlet will get return properties of the Password with ID 123456, using the provided ITGlue API key. The "password" of the Password will be included in the return object. Verbose logging output is sent to the host only.
        .EXAMPLE
            PS C:\> Get-ItGluePassword -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -All

            In this example, the cmdlet will get return properties of all Passwords, using the provided ITGlue API key. The "password" of the Passwords will not be retrieved. Limited logging output is sent to the host only.
        .EXAMPLE
            PS C:\> Get-ItGluePassword -ApiKey (ITG.XXXXXXXXXXXXX | ConvertTo-SecureString -AsPlainText -Force) -Filter @{ organization_id = 123; password_category_id = 5 } -Verbose -LogPath C:\Temp\log.txt

            In this example, the cmdlet will get return properties of all Passwords in org 123, with password_category_id 5, using the provided ITGlue API key. The "password" of the Password will not be retrieved. Verbose logging output is sent to the host and C:\Temp\log.txt
    #>
    [CmdletBinding(DefaultParameterSetName = 'Id')]
    param (
        [Alias("ItGlueApiKey")]
        [Parameter(Mandatory)]
        [SecureString]$ApiKey,

        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [Int]$Id,

        [Parameter(Mandatory, ParameterSetName = 'Filter')]
        [Hashtable]$Filter,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [Switch]$All,

        [Switch]$IncludePassword,

        [Alias("ItGlueUriBase")]
        [String]$UriBase = "https://api.itglue.com",

        [Alias("ItGluePageSize")]
        [Int64]$PageSize = 1000,

        [boolean]$BlockStdErr = $false,

        [string]$EventLogSource,

        [string]$LogPath
    )

    #region Setup
    #region Initialize variables
    $retrievedCollection = [System.Collections.Generic.List[PSObject]]::New()
    $retrievedCollectionWithPassword = @()
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

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    $message = ("{0}: Page size is {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $(If ($PageSize -gt 50) { $PageSize = 50; 'reduced to the API limit of 50' } Else { $PageSize })) # That seems to be the maximum page size for /passwords.
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    #region Auth
    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $header = @{ "x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json" }
        }
        'UserCred' {
            $message = ("{0}: Attempting to generate an access token, using the provided credential." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred -UriBase 'https://itg-api-prod-api-lb-us-west-2.itglue.com' @loggingParams

            If ($accessToken) {
                $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $accessToken" }
            } Else {
                $message = ("{0}: Unable to generate an access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                Out-PsLogging @loggingParams -MessageType Error -Message $message

                Return "Error"
            }
        }
    }
    #endregion Auth
    #endregion Setup

    Switch ($PsCmdlet.ParameterSetName) {
        'Id' {
            #region Single password
            $message = ("{0}: Getting password {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id)
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            Do {
                Try {
                    $retrievedCollection = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/passwords?filter[id]=$Id,show_password=true" -ErrorAction Stop

                    $stopLoop = $true
                } Catch {
                    If ($_.Exception.Message -match 429) {
                        If ($429Count -lt 9) {
                            $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                            $429Count++

                            Start-Sleep -Seconds 60
                        } Else {
                            $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                            Out-PsLogging @loggingParams -MessageType Error -Message $message

                            Return "Error"
                        }
                    } Else {
                        If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 4, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            Out-PsLogging @loggingParams -MessageType Warning -Message $message

                            $loopCount++
                        } Else {
                            $message = ("{0}: Unexpected error getting assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                            Out-PsLogging @loggingParams -MessageType Error -Message $message

                            Return "Error"
                        }
                    }
                }
            }
            While ($stopLoop -eq $false)
            #endregion Single password
        }
        'All' {
            #region Get all passwords in the tenant
            $message = ("{0}: Getting all passwords in the tenant." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $page = 1
            Do {
                Try {
                    Do {
                        $message = ("{0}: Query URL: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$UriBase/passwords?page[number]=$page,page[size]=$PageSize")
                        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                        $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/passwords?page[number]=$page,page[size]=$PageSize" -ErrorAction Stop

                        Foreach ($password in $response.data) {
                            $retrievedCollection.Add($password)
                        }

                        $message = ("{0}: Retrieved page {1} of {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $page, $(If ($response.meta.'total-pages') { $response.meta.'total-pages' } Else { 1 }))
                        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                        If ($response.meta.'next-page') {
                            $page = $response.meta.'next-page'
                        }
                    } While ($retrievedCollection.id.Count -lt $response.meta.'total-count')

                    $stopLoop = $true
                } Catch {
                    If ($_.Exception.Message -match 429) {
                        If ($429Count -lt 9) {
                            $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                            $429Count++

                            Start-Sleep -Seconds 60
                        } Else {
                            $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                            Out-PsLogging @loggingParams -MessageType Error -Message $message

                            Return "Error"
                        }
                    } Else {
                        If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 4, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            Out-PsLogging @loggingParams -MessageType Warning -Message $message

                            $loopCount++
                        } Else {
                            $message = ("{0}: Unexpected error getting assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                            Out-PsLogging @loggingParams -MessageType Error -Message $message

                            Return "Error"
                        }
                    }
                }
            }
            While ($stopLoop -eq $false)
            #endregion Get all passwords in the tenant
        }
        'Filter' {
            #region Get all passwords matching a filter
            #region Validate filter
            $message = ("{0}: Validating the provided filter." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            #Clone so that we can remove items as we're enumerating
            $temp = $Filter.Clone()
            [String]$filterString = ''

            Foreach ($key in $Filter.GetEnumerator()) {
                If ($key.Name -notin @(
                        "id"
                        "name"
                        "organization_id"
                        "password_category_id"
                        "url"
                        "cached_resource_name"
                        "archived"
                    )) {

                    $message = ("{0}: Removing unsupported filter property: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $key.Name)
                    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                    $temp.Remove($key.Name)
                }
            }

            $Filter = $temp

            Foreach ($key in $Filter.GetEnumerator()) {
                $filterString += "filter[$($key.name)]=$($key.value)&"
            }
            #endregion Validate filter

            #region Retrieve the passwords
            $message = ("{0}: Getting passwords matching the filter." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $page = 1
            Do {
                Try {
                    Do {
                        $message = ("{0}: Query URL: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), "$UriBase/passwords?$filterString,`page[number]=$page,page[size]=$PageSize")
                        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                        $response = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/passwords?$filterString`page[number]=$page,page[size]=$PageSize" -ErrorAction Stop

                        Foreach ($password in $response.data) {
                            $retrievedCollection.Add($password)
                        }

                        $message = ("{0}: Retrieved page {1} of {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $page, $(If ($response.meta.'total-pages') { $response.meta.'total-pages' } Else { 1 }))
                        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                        If ($response.meta.'next-page') {
                            $page = $response.meta.'next-page'
                        }
                    } While (($retrievedCollection.id.Count -lt $response.meta.'total-count') -or ($page -lt $response.meta.'total-pages'))

                    $stopLoop = $true
                } Catch {
                    If ($_.Exception.Message -match 429) {
                        If ($429Count -lt 9) {
                            $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                            $429Count++

                            Start-Sleep -Seconds 60
                        } Else {
                            $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                            Out-PsLogging @loggingParams -MessageType Error -Message $message

                            Return "Error"
                        }
                    } Else {
                        If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                            $message = ("{0}: The request timed out and the loop count is {1} of 4, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                            Out-PsLogging @loggingParams -MessageType Warning -Message $message

                            $loopCount++
                        } Else {
                            $message = ("{0}: Unexpected error getting assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                            Out-PsLogging @loggingParams -MessageType Error -Message $message

                            Return "Error"
                        }
                    }
                }
            }
            While ($stopLoop -eq $false)
            #endregion Retrieve the passwords
            #endregion Get all passwords matching a filter
        }
    }

    #region Get password of Password(s)
    If ($IncludePassword -and (($retrievedCollection | Measure-Object).Count -gt 0)) {
        $loopCount = 1
        $429Count = 0
        $i = 0
        Try {
            $retrievedCollectionWithPassword = Foreach ($instance In $retrievedCollection) {
                $i++

                $message = ("{0}: Retrieving password value for `"{1}`". This is password {2} of {3}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $(If ($instance.attributes.name) { $instance.attributes.name } ElseIf ($instance.data.attributes.name) { $instance.data.attributes.name } Else { 'Unknown' }), $i, ($retrievedCollection | Measure-Object).Count)
                If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                If ($instance.data.id) {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations/$($instance.data.attributes.'organization-id')/relationships/passwords/$($instance.data.id)" -ErrorAction Stop).data
                } Else {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations/$($instance.attributes.'organization-id')/relationships/passwords/$($instance.id)" -ErrorAction Stop).data
                }
            }
        } Catch {
            If ($_.Exception.Message -match 429) {
                If ($429Count -lt 9) {
                    $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
                    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                    $429Count++

                    Start-Sleep -Seconds 60
                } Else {
                    $message = ("{0}: Rate limit and rate-limit loop count reached. To prevent errors, {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
                    Out-PsLogging @loggingParams -MessageType Error -Message $message

                    Return "Error"
                }
            } Else {
                If (($loopCount -lt 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 4, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                    Out-PsLogging @loggingParams -MessageType Warning -Message $message

                    $loopCount++
                } Else {
                    $message = ("{0}: Unexpected error getting assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                        ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors -ErrorAction SilentlyContinue).detail), $_.Exception.Message)
                    Out-PsLogging @loggingParams -MessageType Error -Message $message

                    Return "Error"
                }
            }
        }
    } ElseIf (($retrievedCollection | Measure-Object).Count -le 0) {
        $message = ("{0}: No Password instances retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        Out-PsLogging @loggingParams -MessageType Error -Message $message

        Return "Error"
    }
    #endregion Get password of Password(s)

    #region Output
    If ($retrievedCollectionWithPassword) { $retrievedCollection = $retrievedCollectionWithPassword; $retrievedCollectionWithPassword = $null }

    $message = ("{0}: Returning {1} Password instances." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), ($retrievedCollection | Measure-Object).Count)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    If ($retrievedCollection.data.id) { $retrievedCollection.data } Else { $retrievedCollection }
    #endregion Output
} #2023.01.23.0