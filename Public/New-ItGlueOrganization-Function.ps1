Function New-ItGlueOrganization {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or organizations.
        .NOTES
            V2025.06.12.0
                - Initial release
            V2025.06.16.0
            V2025.06.24.0
            V2025.07.08.0
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER OrganizationName
            Enter the name of the desired customer, or "All" to retrieve all organizations.
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
            PS C:\> New-ItGlueOrganization -ItGlueApiKey ITG.XXXXXXXXXXXXX -OrganizationName "Acme Inc."

            In this example, the cmdlet will create a new organization with the name "Acme Inc.". Limited logging output is sent to the host session only.
        .EXAMPLE
            PC C:\> $attributes = @"
            {
                "data": {
                    "type": "organizations",
                    "attributes": {
                        "name": "Acme Inc.",
                        "description": "This is a test organization",
                        "alert-message": "This is an alert message",
                        "quick-notes": "<b>This is a quick note</b>"
                    }
                }
            }
            "@
            PS C:\> New-ItGlueOrganization -ItGlueApiKey ITG.XXXXXXXXXXXXX -OrganizationAttributes $attributes -Verbose

            In this example, the cmdlet will create a new organization with the name "Acme Inc.", description, alert message, and quick note properties are also populated. Verbose logging output is sent to the host session only.
        .EXAMPLE
            PS C:\> New-ItGlueOrganization -ItGlueApiKey ITG.XXXXXXXXXXXXX -OrgName "Acme Inc." -OrgDescription "This is a test organization" -OrgAlert This is an alert message" -OrgQuickNote "<b>This is a quick note</b>" -Verbose -LogPath "C:\Temp\log.txt"

            In this example, the cmdlet will create a new organization with the name "Acme Inc.", description, alert message, and quick note properties are also populated. Verbose logging output is sent to the host session and C:\Temp\log.txt.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [ValidateScript({
                try {
                    $_ | ConvertFrom-Json -ErrorAction Stop
                    $true
                } catch {
                    throw "The input string is not valid JSON."
                }
            })]
        [String]$OrganizationAttributes,

        [String]$OrgName,

        [String]$OrgDescription,

        [String]$OrgAlert,

        [Int]$OrgTypeId,

        [Int]$OrgStatusId,

        [String]$OrgQuickNote,

        [String]$OrgShortName,

        [Int]$OrgParentId,

        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

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
    $method = 'POST'
    $UriBase = $UriBase.TrimEnd('/')
    $response = $null
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

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); Out-PsLogging @loggingParams -MessageType Info -Message $message

    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    #region Auth
    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred @commandParams

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }
    #endregion Auth
    #endregion Setup

    #region Main
    If ($OrganizationAttributes -and (@($OrgName, $OrgDescription, $OrgAlert, $OrgTypeId, $OrgStatusId, $OrgQuickNote, $OrgShortName, $OrgParentId) | Where-Object { $_ -ne $null -and $_ -ne "" }).Count -gt 0) {
        $message = ("{0}: A property string and individual properties were provided, discarding individual properties." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); Out-PsLogging @loggingParams -MessageType Warning -Message $message

        $OrgName = $null
        $OrgDescription = $null
        $OrgAlert = $null
        $OrgTypeId = $null
        $OrgStatusId = $null
        $OrgQuickNote = $null
        $OrgShortName = $null
        $OrgParentId  = $null
    } ElseIf (((-NOT $OrganizationAttributes) -or ($OrganizationAttributes -notmatch '["'']name["'']\s*:')) -and (-NOT $OrgName)) {
        $message = ("{0}: No organization name provided. {1} will exit." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand); Out-PsLogging @loggingParams -MessageType Error -Message $message

        Return "Error"
    }

    If ($OrgName) {
        $attributes = @{}
        If (-NOT [string]::IsNullOrEmpty($OrgName)) { $attributes["name"] = $OrgName }
        If (-NOT [string]::IsNullOrEmpty($OrgDescription)) { $attributes["description"] = $OrgDescription }
        If (-NOT [string]::IsNullOrEmpty($OrgAlert)) { $attributes["alert-message"] = $OrgAlert }
        If ($null -ne $OrgTypeId) { $attributes["organization-type-id"] = $OrgTypeId }
        If ($null -ne $OrgStatusId) { $attributes["organization-status-id"] = $OrgStatusId }
        If (-NOT [string]::IsNullOrEmpty($OrgQuickNote)) { $attributes["quick-notes"] = $OrgQuickNote }
        If (-NOT [string]::IsNullOrEmpty($OrgShortName)) { $attributes["short-name"] = $OrgShortName }
        If ($null -ne $OrgParentId) { $attributes["parent-id"] = $OrgParentId }

        $OrganizationAttributes = (@{
            data = @{
                type       = "organizations"
                attributes = $attributes
            }
        }) | ConvertTo-Json -Depth 3
    }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $method -Headers $header -Uri "$UriBase/organizations" -Body $OrganizationAttributes -ErrorAction Stop

            $stopLoop = $True

            $message = ("{0}: Created the org, '{1}'." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.data.attributes.name); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
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
                If (($loopCount -le 5) -and (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.")) {
                    $message = ("{0}: The request timed out and the loop count is {1} of 5, re-trying the query." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount); Out-PsLogging @loggingParams -MessageType Warning -Message $message

                    $loopCount++
                } Else {
                    $message = ("{0}: Unexpected error creating organization. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

                    Return "Error"
                }
            }
        }
    } While ($stopLoop -eq $false)

    Return $response.data
    #endregion Main
} #2025.07.08.0