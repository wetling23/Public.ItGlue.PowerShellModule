Function Get-ItGlueJsonWebToken {
    <#
        .DESCRIPTION
            Accept a PowerShell credential object or SAML assertion and generate a JSON web token for authentication to the ITGlue API.
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
            V2022.08.28.0
            V2022.08.29.0
            V2022.08.29.1
            V2023.03.30.0
        .PARAMETER Credential
            ITGlue credential object for the desired local account.
        .PARAMETER SamlAssertion
            Represents an SSO SAML assertion for the desired local account.
        .PARAMETER UriBase
            Base URL for the ITGlue customer.
        .PARAMETER BlockStdErr
            When set to $True, the script will block "Write-Error". Use this parameter when calling from wscript. This is required due to a bug in wscript (https://groups.google.com/forum/#!topic/microsoft.public.scripting.wsh/kIvQsqxSkSk).
        .PARAMETER EventLogSource
            When included, (and when LogPath is null), represents the event log source for the Application log. If no event log source or path are provided, output is sent only to the host.
        .PARAMETER LogPath
            When included (when EventLogSource is null), represents the file, to which the cmdlet will output will be logged. If no path or event log source are provided, output is sent only to the host.
        .EXAMPLE
            PS C:\> Get-ItGlueJsonWebToken -Credential (Get-Credential) -UriBase https://company.itglue.com -Verbose

            In this example, the cmdlet connects to https://company.itglue.com and generates an access token for the user specified in Get-Credential. Verbose logging output is sent to the host only.
        .EXAMPLE
            PS C:\> $samlAssertion = '<a SAML assertion string, generated by your IdP>'
            PS C:\> Get-ItGlueJsonWebToken -Credential $samlAssertion -UriBase https://company.itglue.com -LogPath C:\Temp\log.txt

            In this example, the cmdlet connects to https://company.itglue.com and generates an access token for the user specified in the SAML assertion. Limited logging output is written to the host and C:\Temp\log.txt.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SSO')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Cred')]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory, ParameterSetName = 'SSO')]
        [String]$SamlAssertion,

        [Parameter(Mandatory)]
        [ValidatePattern("^https?:\/\/[a-zA-Z0-9]+\.itglue\.com$")]
        [String]$UriBase,

        [Boolean]$BlockStdErr = $false,

        [String]$EventLogSource,

        [String]$LogPath
    )

    #region Setup
    #region Initialize variables
    $UriBase = $UriBase.TrimEnd('/')
    $httpVerb = 'POST'

    If ($PsCmdlet.ParameterSetName -eq "SSO") {
        $url = "$UriBase/saml/consume"
        $headers = @{
            'Content-Type' = 'application/json'
        }
        $base = @{
            saml_response = $($SamlAssertion)
        } | ConvertTo-Json
    } Else {
        $url = "$UriBase/login?generate_jwt=1&sso_disabled=1"
        $headers = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/json' }
        $base = @{
            "user" = @{
                "email"    = $Credential.UserName
                "password" = $Credential.GetNetworkCredential().password
            }
        } | ConvertTo-Json
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

    $message = ("{0}: Beginning {1}." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $MyInvocation.MyCommand)
    Out-PsLogging @loggingParams -MessageType Info -Message $message

    $message = ("{0}: Operating in the {1} parameter set." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $PsCmdlet.ParameterSetName)
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
    #endregion Setup

    #region Generate refresh token
    $message = ("{0}: Attempting to initiate a web session." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    # Per Kaseya support (a software dev), the MaximumRedirection parameter can be 1. It has also worked as 0.
    $response = Invoke-WebRequest -Method $httpVerb -UseBasicParsing -Uri $url -Headers $headers -Body $base -MaximumRedirection 1 -SessionVariable 'session' -ErrorAction SilentlyContinue

    If (($response.StatusCode -eq 302) -and ($response)) {
        $message = ("{0}: Web session initiated." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }
    } Else {
        $message = ("{0}: Unexpected error generating a refresh token. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        Out-PsLogging @loggingParams -MessageType Error -Message $message

        Return "Error"
    }

    If ($session) {
        $message = ("{0}: Attempting to generate a refresh token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        Try {
            $refreshTokenResponse = Invoke-WebRequest "$UriBase/jwt/refresh" -WebSession $session -ContentType "application/json" -ErrorAction Stop
        } Catch {
            $message = ("{0}: Unexpected error requesting refresh token. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
            Out-PsLogging @loggingParams -MessageType Error -Message $message

            Return "Error"
        }

        If ($refreshTokenResponse.StatusCode -eq 200) {
            $message = ("{0}: Successfully generated a refresh token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
            If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

            $refreshToken = ($refreshTokenResponse | ConvertFrom-Json).token
        } Else {
            $message = ("{0}: Failed to generate refresh token.`r`nStatus code:`r`n`t{1}`r`nStatus description:`r`n`t{2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $refreshTokenResponse.StatusCode, $refreshTokenResponse.StatusDescription)
            Out-PsLogging @loggingParams -MessageType Error -Message $message

            Return "Error"
        }
    }
    #endregion Generate refresh token

    #region Generate access token
    $message = ("{0}: Attempting to generate an access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
    If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

    Try {
        $accessTokenResponse = Invoke-WebRequest "$UriBase/jwt/token?refresh_token=$refreshToken" -WebSession $session -ContentType "application/json" -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error requesting access token. Error: {1}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $_.Exception.Message)
        Out-PsLogging @loggingParams -MessageType Error -Message $message

        Return "Error"
    }

    If ($accessTokenResponse.StatusCode -eq 200) {
        $message = ("{0}: Successfully generated an access token." -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"))
        If ($loggingParams.Verbose) { Out-PsLogging @loggingParams -MessageType Verbose -Message $message }

        $accessToken = ($accessTokenResponse | ConvertFrom-Json).token
    } Else {
        $message = ("{0}: Failed to generate access token.`r`nStatus code:`r`n`t{1}`r`nStatus description:`r`n`t{2}" -f ([datetime]::Now).ToString("yyyy-MM-dd`THH:mm:ss"), $refreshTokenResponse.StatusCode, $refreshTokenResponse.StatusDescription)
        Out-PsLogging @loggingParams -MessageType Error -Message $message

        Return "Error"
    }
    #region Generate access token

    Return $accessToken
} #2023.03.30.0