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