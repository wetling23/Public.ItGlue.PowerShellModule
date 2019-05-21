Function Get-ItGlueDeviceConfig {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or more device configs.
        .NOTES
            V1.0.0.0 date: 25 March 2019
                - Initial release.
            V1.0.0.1 date: 2 April 2019
                - Updated in-line documentation.
            V1.0.0.2 date: 20 May 2019
                - Updated rate-limit detection.
        .PARAMETER ComputerName
            Enter the hostname of the desired device config, or "All" to retrieve all device configs.
        .PARAMETER ItGlueCustomerId
            Desired customer's ITGlue organization ID.
        .PARAMETER ItGlueApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER ItGlueUserCred
            ITGlue credential object for the desired local account.
        .PARAMETER ItGlueUriBase
            Base URL for the ITGlue API.
        .PARAMETER ItGluePageSize
            Page size when requesting ITGlue resources via the API.
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -ItGlueApiKey ITG.XXXXXXXXXXXXX -ComputerName All

            In this example, the cmdlet will get all ITGlue device configurations, using the provided ITGlue API key. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -ItGlueUserCred (Get-Credential) -ComputerName server1 -BlockLogging -Verbose

            In this example, the cmdlet will get all device configurations for "server1", using the provided ITGlue user credentials. Output will only be sent to the host session.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -ItGlueUserCred (Get-Credential) -ItGlueCustomerId 123456 -BlockLogging -Verbose

            In this example, the cmdlet will get all device configurations for customer with ID 123456, using the provided ITGlue user credentials. Output will only be sent to the host session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ITGlueApiKey')]
    param (
        [Parameter(Mandatory = $True)]
        [ValidatePattern("^All$|^[a-z,A-Z,0-9]+")]
        [string]$ComputerName,

        [int64]$ItGlueCustomerId,

        [Parameter(ParameterSetName = 'ITGlueApiKey', Mandatory)]
        [SecureString]$ItGlueApiKey,

        [Parameter(ParameterSetName = 'ITGlueUserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$ItGlueUserCred,

        [string]$ItGlueUriBase = "https://api.itglue.com",

        [int64]$ItGluePageSize = 1000,

        [string]$EventLogSource = 'ItGluePowerShellModule',

        [switch]$BlockLogging
    )

    If (-NOT($BlockLogging)) {
        $return = Add-EventLogSource -EventLogSource $EventLogSource

        If ($return -ne "Success") {
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f (Get-Date -Format s), $EventLogSource)
            Write-Verbose $message

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Initialize variables.
    $stopLoop = $false
    Switch ($PsCmdlet.ParameterSetName) {
        'ITGlueApiKey' {
            $message = ("{0}: Setting header with API key." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

            $ItGlueApiHeader = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ItGlueApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'ITGlueUserCred' {
            $message = ("{0}: Setting header with user-access token." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

            $accessToken = Get-ItGlueJsonWebToken -Credential $ItGlueUserCred

            $ItGlueUriBase = 'https://api-mobile-prod.itglue.com/api'
            $ItGlueApiHeader = @{ }
            $ItGlueApiHeader.add('cache-control', 'no-cache')
            $ItGlueApiHeader.add('content-type', 'application/vnd.api+json')
            $ItGlueApiHeader.add('authorization', "Bearer $(($accessToken.Content | ConvertFrom-Json).token)")
        }
    }

    $message = ("{0}: Getting all devices configurations." -f (Get-Date -Format s))
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    If ($ComputerName -eq "All") {
        $loopCount = 0
        Do {
            Try {
                $loopCount++

                $allDeviceCount = Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/configurations?page[size]=$ItGluePageSize" -ErrorAction Stop

                $stopLoop = $True
            }
            Catch {
                If ($loopCount -ge $MaxLoopCount) {
                    $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                    If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
                If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    $ItGluePageSize = $ItGluePageSize / 2

                    $message = ("{0}: Rate limit exceeded, retrying in 60 seconds with `$ITGluePageSize == {1}." -f (Get-Date -Format s), $ItGluePageSize)
                    If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417 }

                    Start-Sleep -Seconds 60
                }
                Else {
                    $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        $loopCount = 0
        $deviceConfigurations = for ($i = 1; $i -le $($allDeviceCount.meta.'total-pages'); $i++) {
            $deviceConfigQueryBody = @{
                "page[size]"   = $ItGluePageSize
                "page[number]" = $i
            }

            $message = ("Getting page {0} of {1} of the device configurations." -f $i, $allDeviceCount.meta.'total-pages')
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

            Do {
                Try {
                    $loopCount++

                    Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/configurations" -Body $deviceConfigQueryBody -ErrorAction Stop

                    $stopLoop = $True
                }
                Catch {
                    If ($loopCount -ge $MaxLoopCount) {
                        $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                        $ItGluePageSize = $ItGluePageSize / 2

                        $message = ("{0}: Rate limit exceeded, retrying in 60 seconds with `$ITGluePageSize == {1}." -f (Get-Date -Format s), $ItGluePageSize)
                        If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417 }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting flexible assets. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)
        }

        $message = ("{0}: Found {1} device configurations." -f (Get-Date -Format s), $deviceConfigurations.count)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        Return $deviceConfigurations.data
    }
    Else {
        If ($ItGlueCustomerId) {
            $message = ("Getting devices for customer with ID {0}." -f $ItGlueCustomerId)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $loopCount = 0
            Do {
                Try {
                    $allDeviceCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$ItGlueUriBase/configurations?page[size]=$ItGluePageSize&filter[organization-id]=$ItGlueCustomerId" -ErrorAction Stop
                }
                Catch {
                    If ($loopCount -ge $MaxLoopCount) {
                        $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                        $ItGluePageSize = $ItGluePageSize / 2

                        $message = ("{0}: Rate limit exceeded, retrying in 60 seconds with `$ITGluePageSize == {1}." -f (Get-Date -Format s), $ItGluePageSize)
                        If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417 }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting flexible assets. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $loopCount = 0
            $deviceConfigurations = for ($i = 1; $i -le $($allDeviceCount.meta.'total-pages'); $i++) {
                $deviceConfigQueryBody = @{
                    "page[size]"              = $ItGluePageSize
                    "page[number]"            = $i
                    "filter[organization-id]" = $ItGlueCustomerId
                }

                $message = ("Getting page {0} of {1} of the device configurations." -f $i, $allDeviceCount.meta.'total-pages')
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

                Do {
                    Try {
                        $loopCount++

                        Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/configurations" -Body $deviceConfigQueryBody -ErrorAction Stop

                        $stopLoop = $True
                    }
                    Catch {
                        If ($loopCount -ge $MaxLoopCount) {
                            $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                            If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }
                        If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                            $ItGluePageSize = $ItGluePageSize / 2

                            $message = ("{0}: Rate limit exceeded, retrying in 60 seconds with `$ITGluePageSize == {1}." -f (Get-Date -Format s), $ItGluePageSize)
                            If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417 }

                            Start-Sleep -Seconds 60
                        }
                        Else {
                            $message = ("{0}: Unexpected error getting flexible assets. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }
                    }
                }
                While ($stopLoop -eq $false)
            }

            $message = ("Filtering for devices matching {0}." -f $ComputerName)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            Return ($deviceConfigurations | Where-Object { $_.attributes.name -match $ComputerName }).data

            #Return $deviceConfigurations.data
        }
        Else {
            $stopLoop = $false
            $loopCount = 0
            Do {
                Try {
                    $loopCount++

                    $allDeviceCount = Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/configurations?page[size]=$ItGluePageSize" -ErrorAction Stop

                    $stopLoop = $True
                }
                Catch {
                    If ($loopCount -ge $MaxLoopCount) {
                        $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                        $ItGluePageSize = $ItGluePageSize / 2

                        $message = ("{0}: Rate limit exceeded, retrying in 60 seconds with `$ITGluePageSize == {1}." -f (Get-Date -Format s), $ItGluePageSize)
                        If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417 }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $stopLoop = $false
            $loopCount = 0
            $deviceConfigurations = for ($i = 1; $i -le $($allDeviceCount.meta.'total-pages'); $i++) {
                $deviceConfigQueryBody = @{
                    "page[size]"   = $ItGluePageSize
                    "page[number]" = $i
                }

                $message = ("Getting page {0} of {1} of the device configurations." -f $i, $allDeviceCount.meta.'total-pages')
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

                Do {
                    Try {
                        $loopCount++

                        Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/configurations" -Body $deviceConfigQueryBody -ErrorAction Stop

                        $stopLoop = $True
                    }
                    Catch {
                        If ($loopCount -ge $MaxLoopCount) {
                            $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                            If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }
                        If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                            $ItGluePageSize = $ItGluePageSize / 2

                            $message = ("{0}: Rate limit exceeded, retrying in 60 seconds with `$ITGluePageSize == {1}." -f (Get-Date -Format s), $ItGluePageSize)
                            If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417 }

                            Start-Sleep -Seconds 60
                        }
                        Else {
                            $message = ("{0}: Unexpected error getting flexible assets. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }
                    }
                }
                While ($stopLoop -eq $false)
            }

            $message = ("{0}: Found {1} device configurations." -f (Get-Date -Format s), $deviceConfigurations.count)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $message = ("Filtering for devices matching {0}." -f $ComputerName)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            Return ($deviceConfigurations.data | Where-Object { $_.attributes.name -match $ComputerName })
        }
    }
} #1.0.0.2