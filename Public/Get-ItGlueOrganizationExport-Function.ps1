Function Get-ItGlueOrganizationExport {
    <#
        .DESCRIPTION
            Accept an ITGlue optional org ID return ITGlue export properties. Requires an access token, API key authentication is not supported.
        .NOTES
            V2022.09.09.0
                - Initial release.
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER OrganizationId
            Represents the desired customer's ITGlue organization ID.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account. Will be used to generate an access token.
        .PARAMETER AccessToken
            Represents a pre-generated ITGlue access token.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganizationExport -AccessToken (Get-ItGlueJsonWebToken -SamlAssertion <IdP SAML assertion string> -UriBase https://company.itglue.com) -OrganizationId 123 -Verbose -LogPath C:\Temp\log.txt

            In this example, the cmdlet will use the generated access token key and will query ITGlue for all available organization exports. The returned data will be limited to those exports created for the organization with ID 123. Verbose logging output is written to the host and C:\Temp\log.txt.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganizationExport -AccessToken (Get-ItGlueJsonWebToken -SamlAssertion <IdP SAML assertion string> -UriBase https://company.itglue.com)

            In this example, the cmdlet will use the generated access token key and will query ITGlue for all available organization exports. The returned data will include all available exports. Limited logging output is written to the host only.
    #>
    [CmdletBinding()]
    param (
        [Int]$OrganizationId,

        [Alias("ItGlueUserCred")]
        [System.Management.Automation.PSCredential]$UserCred,

        [Alias("ItGlueAccessToken")]
        [SecureString]$AccessToken,

        [Alias("ItGlueUriBase")]
        [String]$UriBase = "https://itg-api-prod-api-lb-us-west-2.itglue.com",

        [Boolean]$BlockStdErr = $false,

        [String]$EventLogSource,

        [String]$LogPath
    )

    #region Setup
    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    #regional Initialize variables
    $stopLoop = $false
    $loopCount = 1
    $UriBase = $UriBase.TrimEnd('/')
    #endregional Initialize variables

    #region Logging
    # Setup parameters for splatting.
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
                Verbose    = $true
                ScreenOnly = $true
            }
        }
    } Else {
        If ($EventLogSource -and (-NOT $LogPath)) {
            $loggingParams = @{
                Verbose        = $False
                EventLogSource = $EventLogSource
            }
        } ElseIf ($LogPath -and (-NOT $EventLogSource)) {
            $loggingParams = @{
                Verbose = $False
                LogPath = $LogPath
            }
        } Else {
            $loggingParams = @{
                Verbose    = $False
                ScreenOnly = $true
            }
        }
    }
    #endregion Logging

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Out-PsLogging @loggingParams -MessageType Info -Message $message

    #region Auth
    If ($UserCred -and $AccessToken) {
        $message = ("{0}: Both a credential and access token were provided. Ignoring the credential." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $header = @{
            "Authorization" = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)))"
            'Content-Type'  = 'application/vnd.api+json'
            'Accept'        = 'application/json, text/plain'
        }
    } ElseIf (-NOT($UserCred) -and $AccessToken) {
        # This header definition /could/ be combined with the condition above, but I wanted different messages.
        $message = ("{0}: Using the provided access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $header = @{
            "Authorization" = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)))"
            'Content-Type'  = 'application/vnd.api+json'
            'Accept'        = 'application/json, text/plain'
        }
    } ElseIf ($UserCred -and -NOT($AccessToken)) {
        $message = ("{0}: Attempting to generate an access token, using the provided credential." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred -UriBase $UriBase @loggingParams

        If ($AccessToken) {
            $header = @{ 'content-type' = 'application/vnd.api+json'; 'accept' = 'application/json, text/plain'; 'authorization' = "Bearer $accessToken" }
        } Else {
            $message = ("{0}: Unable to generate an access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            Out-PsLogging @loggingParams -MessageType Error -Message $message

            Return "Error"
        }
    } Else {
        $message = ("{0}: No authentication mechanisms provided. Re-run the command with either an access token or a user credential, authorized to create an access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Return "Error"
    }
    #endregion Auth
    #endregion Setup

    #region Get export list
    $commandParams = @{
        Method          = 'GET'
        UseBasicParsing = $true
        Headers         = $header
        ErrorAction     = 'Stop'
        Uri             = "$UriBase/api/exports.json"
    }

    $message = ("{0}: Invoking REST command." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    Do {
        Try {
            $response = Invoke-RestMethod @commandParams

            $stopLoop = $true
        } Catch {
            If (($_.Exception.Message -match 429) -and ($loopCount -lt 6)) {
                $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again. This is loop {1} of five." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount)
                If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                Start-Sleep -Seconds 60

                $loopCount++
            } Else {
                $message = ("{0}: Unexpected error creating export. To prevent errors, {1} will exit. Error details, if present:`r`n`t
    Error title: {2}`r`n`t
    Error detail is: {3}`r`t`n
    PowerShell returned: {4}" -f `
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                Out-PsLogging @loggingParams -MessageType Error -Message $message

                Return "Error"
            }
        }
    } While ($stopLoop -eq $false)

    If ($response.data.id) {
        $message = ("{0}: Successfully retrieved the export list." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
    } Else {
        $message = ("{0}: Zero exports retrieved." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Return
    }
    #endregion Get export list

    #region Return data
    If ($OrganizationId) {
        Foreach ($export in $response.data) {
            If ($export.attributes.'organization-id' -eq $OrganizationId) {
                $message = ("{0}: Found an export for org {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $OrganizationId)
                If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                $export
            }
        }
    } Else {
        $message = ("{0}: Returning all existing exports." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $response.data
    }
    #endregion Return data
} #2022.09.09.0