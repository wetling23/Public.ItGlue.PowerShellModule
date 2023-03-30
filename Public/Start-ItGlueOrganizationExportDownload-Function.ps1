Function Start-ItGlueOrganizationExportDownload {
    <#
        .DESCRIPTION
            Accept an ITGlue organization-export ID and download the exported data. Requires an access token, API key authentication is not supported.
        .NOTES
            V2022.09.09.0
                - Initial release.
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ExportId
            Represents the desired organization-export's ID.
        .PARAMETER OutputFile
            Represents the path and file name, to which the export will be downloaded.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Start-ItGlueOrganizationExportDownload -ExportId 123,654 -OutFile C:\it\123.zip,C:\Temp\654.zip -Verbose -LogPath C:\Temp\log.txt

            In this example, the cmdlet will download exports 123 and 654 to C:\Temp\123.zip and C:\Temp\654.zip (respectively). Verbose logging output is written to the host and C:\Temp\log.txt.
    #>
    [CmdletBinding()]
    param (
        [Int[]]$ExportId,

        [Parameter(Mandatory)]
        [Uri]$DownloadUrl,

        [Parameter(Mandatory)]
        [ValidateScript({
                If (-NOT ($_.FullName | Test-Path) ) {
                    Throw "File or folder does not exist."
                }
                If (-NOT ($_.FullName | Test-Path -PathType Leaf) ) {
                    Throw "The Path argument must be a file. Folder paths are not allowed."
                }
                Return $true
            })]
        [System.IO.FileInfo[]]$OutputFile,

        [Alias("ItGlueUserCred")]
        [System.Management.Automation.PSCredential]$UserCred,

        [Alias("ItGlueAccessToken")]
        [SecureString]$AccessToken,

        [Boolean]$BlockStdErr = $false,

        [String]$EventLogSource,

        [String]$LogPath
    )

    #region Setup
    $message = ("{0}: Operating in the {1} parameterset." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    #regional Initialize variables
    $i = 0
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
    #endregion Setup

    #region Download exports
    Foreach ($id in $ExportId) {
        $message = ("{0}: Attempting to download export {1} to {2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $id, $OutputFile[$i].FullName)
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Try {
            $downloader = New-Object System.Net.WebClient
            $downloader.DownloadFile($DownloadUrl, $OutputFile[$i].FullName)
            $downloader.Dispose()
        } Catch {
            $message = ("{0}: Unexpected error downloading the export. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            Out-PsLogging @loggingParams -MessageType Error -Message $message

            Return "Error"
        }

        $i++
    }
    #endregion Download exports
} #2022.09.09.0