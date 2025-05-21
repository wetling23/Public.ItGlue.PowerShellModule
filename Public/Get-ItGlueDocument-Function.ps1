Function Get-ItGlueDocument {
    <#
        .DESCRIPTION
            Accept an ITGlue org ID and a document ID and return the properties/content/attachments. Requires an access token, API key authentication is not supported.
        .NOTES
            V2022.03.30.0
                - Initial release.
            V2023.07.07.0
            V2023.07.16.0
            V2024.05.10.0
            V2024.10.15.0
            V2025.02.06.0
            V2025.02.18.0
            V2025.05.15.0
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER OrganizationId
            Represents the desired customer's ITGlue organization ID.
        .PARAMETER Id
            Represents the ID of the desired document.
        .PARAMETER IncludeAttachment
            When included, any attachments to the desired document will be downloaded.
        .PARAMETER OutputDirectory
            Path to which the cmdlet will download attached files, when -IncludeAttachment is specified.
        .PARAMETER Tenant
            ITGlue tenant name (aka company or portal). Required to build the download URL when -IncludeAttachment is specified.
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
            PS C:\> Get-ItGlueDocument -AccessToken (Get-ItGlueJsonWebToken -SamlAssertion <IdP SAML assertion string> -UriBase https://company.itglue.com) -OrganizationId 123 -Id 456 -Verbose -LogPath C:\Temp\log.txt

            In this example, the cmdlet will use the generated access token key to get the ITGlue document with ID 456 from the orgianization with ID 123. Verbose logging output is written to the host and C:\Temp\log.txt.
        .EXAMPLE
            PS C:\> Get-ItGlueDocument -AccessToken (Get-ItGlueJsonWebToken -SamlAssertion <IdP SAML assertion string> -UriBase https://company.itglue.com) -OrganizationId 123 -Id 456 -IncludeAttachment -OutputDirectory C:\Temp -Tenant acme

            In this example, the cmdlet will use the generated access token key to get the ITGlue document with ID 456 from the orgianization with ID 123. Any files attached to document 123 will be downloaded to C:\Temp (through https://acme.itglue.com). Limited logging output is written only to the host.
    #>
    [CmdletBinding(DefaultParameterSetName = 'NoAttachment')]
    param (
        [Parameter(Mandatory)]
        [Int]$OrganizationId,

        [Parameter(Mandatory)]
        [Alias("DocumentId")]
        [Int]$Id,

        [Parameter(Mandatory, ParameterSetName = 'IncludeAttachments')]
        [Switch]$IncludeAttachment,

        [Parameter(Mandatory, ParameterSetName = 'IncludeAttachments')]
        [ValidateScript({
                If (-NOT ($_ | Test-Path) ) {
                    Throw "File or folder does not exist."
                }
                If (($_ | Test-Path -PathType Leaf) ) {
                    Throw "The Path argument must be a folder. File paths are not allowed."
                }
                Return $true
            })]
        [System.IO.FileInfo]$OutputDirectory,

        [Parameter(Mandatory)]
        [String]$Tenant,

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
    If ($UserCred -and $AccessToken) {
        $message = ("{0}: Both a credential and access token were provided. Ignoring the credential." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $header = @{
            "Authorization" = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)))"
            'Content-Type'  = 'application/vnd.api+json'
            'Accept'        = 'application/json, text/plain'
        }
    } ElseIf (-NOT($UserCred) -and $AccessToken) {
        # This /could/ be combined with the option above, but I wanted different messages.
        $message = ("{0}: Using the provided access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $header = @{
            "Authorization" = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)))"
            'Content-Type'  = 'application/vnd.api+json'
            'Accept'        = 'application/json, text/plain'
        }
    } ElseIf ($UserCred -and -NOT($AccessToken)) {
        $message = ("{0}: Attempting to generate an access token, using the provided credential." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $message = ("{0}: Setting header with user-access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred -UriBase $UriBase @loggingParams

        If ($AccessToken) {
            $header = @{ 'content-type' = 'application/vnd.api+json'; 'accept' = 'application/json, text/plain'; 'authorization' = "Bearer $accessToken" }
        } Else {
            $message = ("{0}: Unable to generate an access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); Out-PsLogging @loggingParams -MessageType Error -Message $message

            Return "Error"
        }
    } Else {
        $message = ("{0}: No authentication mechanisms provided. Re-run the command with either an access token or a user credential, authorized to create an access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss")); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Return "Error"
    }
    #endregion Auth
    #endregion Setup

    #region Get documents
    $message = ("{0}: Attempting to get document {1} for org {2}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $Id, $OrganizationId); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    $commandParams = @{
        Method          = 'GET'
        UseBasicParsing = $true
        Headers         = $header
        ErrorAction     = 'Stop'
        Uri             = "https://$Tenant.itglue.com/$OrganizationId/docs/$Id.json"
    }

    Do {
        Try {
            $response = Invoke-RestMethod @commandParams

            $stopLoop = $true
        } Catch {
            If (($_.Exception.Message -match 429) -and ($loopCount -lt 6)) {
                $message = ("{0}: Rate limit reached. Sleeping for 60 seconds before trying again. This is loop {1} of five." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $loopCount); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                Start-Sleep -Seconds 60

                $loopCount++
            } ElseIf (($_.Exception.Message -match 403) -or ($_.Exception.Message -match 'Internal Server Error')) {
                $commandParams.Uri = "$UriBase/api/organizations/$OrganizationId/relationships/documents/$Id`?include=attachments"

                $message = ("{0}: Exception: {1}. Attempting alternative URI ({2})." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message, $commandParams.Uri); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

                Try {
                    $response = Invoke-RestMethod @commandParams

                    $stopLoop = $true
                } Catch {
                    If ($_.Exception.Message -match '401') {
                        $message = ("{0}: 401 error while getting document. Update access token or credential and try again. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

                        Return "401"
                    } Else {
                        $message = ("{0}: Unexpected error getting document. To prevent errors, {1} will exit. Error details, if present:`r`n`t
    Error title: {2}`r`n`t
    Error detail is: {3}`r`t`n
    PowerShell returned: {4}" -f `
                            ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        Out-PsLogging @loggingParams -MessageType Error -Message $message

                        Return "Error"
                    }
                }
            } ElseIf ($_.Exception.Message -match '401') {
                $message = ("{0}: Encountered 401 error while getting document. Update access token or credential and try again. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

                Return "401"
            } Else {
                $message = ("{0}: Unexpected error getting document. To prevent errors, {1} will exit. Error details, if present:`r`n`t
    Error title: {2}`r`n`t
    Error detail is: {3}`r`t`n
    PowerShell returned: {4}" -f `
                    ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand, ($_.ErrorDetails.message | ConvertFrom-Json).errors.title, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                Out-PsLogging @loggingParams -MessageType Error -Message $message

                Return "Error"
            }
        }

        If (($response.attachments) -and ($IncludeAttachment)) {
            $message = ("{0}: Preparing to download {1} attachments." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.attachments.id.Count); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $cli = New-Object System.Net.WebClient

            Foreach ($item in $header.GetEnumerator()) {
                $cli.Headers[$item.name] = $item.value
            }

            Foreach ($file in $response.attachments) {
                Try {
                    $cli.DownloadFile(("https://{0}.itglue.com{1}" -f $Tenant, $file.url), ('{0}{1}{2}' -f $OutputDirectory.FullName, $(If ($OutputDirectory.FullName -notmatch '\\$') { '\' }), $file.name))
                } Catch {
                    $message = ("{0}: Unexpected error downloading attachment ({1}). To prevent errors, {2} will exit. Error: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $file.name, $MyInvocation.MyCommand, $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

                    Return "Error"
                }
            }
        } ElseIf (($response.included) -and ($IncludeAttachment)) {
            $message = ("{0}: Preparing to download {1} attachments." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.included.attributes.id.Count); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $cli = New-Object System.Net.WebClient

            Foreach ($item in $header.GetEnumerator()) {
                $cli.Headers[$item.name] = $item.value
            }

            Try {
                $cli.DownloadFile(("{0}" -f $response.included.attributes.'download-url'), ('{0}{1}{2}' -f $OutputDirectory.FullName, $(If ($OutputDirectory.FullName -notmatch '\\$') { '\' }), $response.included.attributes.'attachment-file-name'))
            } Catch {
                $message = ("{0}: Unexpected error downloading attachment ({1}). To prevent errors, {2} will exit. Error: {3}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.included.attributes.'attachment-file-name', $MyInvocation.MyCommand, $_.Exception.Message); Out-PsLogging @loggingParams -MessageType Error -Message $message

                Return "Error"
            }
        }
    } While ($stopLoop -eq $false)
    #endregion Get documents

    If ($response.id.Count -ge 1) {
        $message = ("{0}: Returning document properties." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.data.id.Count); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Return $response
    } ElseIf ($response.included.id.Count -eq 1) {
        $message = ("{0}: Returning uploaded-file properties." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.data.id.Count); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Return $response.included.attributes
    } ElseIf ($response.data.id.Count -eq 1) {
        $message = ("{0}: Returning document properties." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $response.data.id.Count); If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Return $response.data.attributes
    }
} #2025.05.15.0