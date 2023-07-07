Function Get-ItGlueDocumentFolder {
    <#
        .DESCRIPTION
            Accept an ITGlue org ID and (optionally) a folder ID and return the properties. Requires an access token, API key authentication is not supported.
        .NOTES
            V2022.03.02.0
                - Initial release.
            V2022.08.29.0
            V2022.09.09.0
            V2023.01.06.0
            V2023.06.30.0
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER OrganizationId
            Represents the desired customer's ITGlue organization ID.
        .PARAMETER Id
            Represents the ID of the desired folder.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account. Will be used to generate an access token.
        .PARAMETER AccessToken
            Represents a pre-generated ITGlue access token.
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
            PS C:\> Get-ItGlueDocumentFolder -AccessToken (Get-ItGlueJsonWebToken -SamlAssertion <IdP SAML assertion string> -UriBase https://company.itglue.com) -OrganizationId 123 -Id 456 -Verbose -LogPath C:\Temp\log.txt

            In this example, the cmdlet will use the generated access token key to get the ITGlue document folder with ID 456 from the orgianization with ID 123. Verbose logging output is written to the host and C:\Temp\log.txt.
    #>
    [CmdletBinding(DefaultParameterSetName = 'OrgFilterOnly')]
    param (
        [Parameter(Mandatory)]
        [Int]$OrganizationId,

        [Parameter(Mandatory, ParameterSetName = 'IdFilter')]
        [Alias("FolderId")]
        [Int]$Id,

        [Alias("ItGlueUserCred")]
        [System.Management.Automation.PSCredential]$UserCred,

        [Alias("ItGlueAccessToken")]
        [SecureString]$AccessToken,

        [Alias("ItGlueUriBase")]
        [String]$UriBase = "https://itg-api-prod-api-lb-us-west-2.itglue.com",

        [Alias("ItGluePageSize")]
        [Int]$PageSize = 1000,

        [Boolean]$BlockStdErr = $false,

        [String]$EventLogSource,

        [String]$LogPath
    )

    #region Setup
    #region Initialize variables
    $stopLoop = $false
    $loopCount = 1
    $UriBase = $UriBase.TrimEnd('/')
    $folders = [System.Collections.Generic.List[PSObject]]::New()
    $page = 1

    If ($Id) { $PageSize = 1 }
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
    Out-PsLogging @loggingParams -MessageType Info -Message $message

    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

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
        # This /could/ be combined with the option above, but I wanted different messages.
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

    #region Get folders
    $commandParams = @{
        Method          = 'GET'
        UseBasicParsing = $true
        Headers         = $header
        ErrorAction     = 'Stop'
        Uri             = "$UriBase/api/organizations/$OrganizationId/relationships/document_folders?page[size]=$PageSize&page[number]=$page"
    }

    If ($PsCmdlet.ParameterSetName -eq "IdFilter") {
        $commandParams.Uri = $commandParams.Uri -replace '\?.*', "`/$Id"
    }

    $message = ("{0}: Connecting to {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $commandParams.Uri)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    Do {
        $response = $null
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
                $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. Error details, if present:`r`n`t
    Error title: {2}`r`n`t
    Error detail is: {3}`r`t`n
    PowerShell returned: {4}" -f `
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                Out-PsLogging @loggingParams -MessageType Error -Message $message

                Return "Error"
            }
        }

        If ($response.data.id.Count -ge 1) {
            Foreach ($folder in $response.data) {
                $folders.Add($folder)
            }
        }

        Switch ($PsCmdlet.ParameterSetName) {
            'OrgFilterOnly' {
                If ($response -and ($response.meta.'total-count') -ne $folders.id.Count) {
                    $page++
                    $stopLoop = $false
                    $commandParams.Uri = "$UriBase/api/organizations/$OrganizationId/relationships/document_folders?page[size]=$PageSize&page[number]=$page"
                }
            }
            'IdFilter' {
                $stopLoop = $true
            }
        }
    } While ($stopLoop -eq $false)
    #endregion Get folder

    If ($response.data.id.Count -ge 1) {
        $message = ("{0}: Returning {1} document folders." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $folders.id.Count)
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Return $folders
    }
} #2023.07.07.0