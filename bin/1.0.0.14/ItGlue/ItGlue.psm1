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
        $stopLoop = $false
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
            $stopLoop = $false
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
Function Get-ItGlueFlexibleAssetInstance {
    <#
        .DESCRIPTION
            Gets all instances of a flexible asset, based on the ID.
        .NOTES
            V1.0.0.0 date: 21 March 2019
                - Initial release.
            V1.0.0.1 date: 2 April 2019
                - Updated in-line documentation.
            V1.0.0.2 date: 5 April 2019
                - Added support for timeout response and max loop count.
            V1.0.0.3 date: 22 April 2019
                - Fixed reference to specific flexible asset, in logging.
            V1.0.0.4 date: 24 April 2019
                - Added $MaxLoopCount parameter.
            V1.0.0.5 date: 20 May 2019
                - Updated rate-limit detection.
        .PARAMETER ItGlueApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER ItGlueUserCred
            ITGlue credential object for the desired local account.
        .PARAMETER FlexibleAssetId
            Identifier ID for the desired flexible asset type.
        .PARAMETER MaxLoopCount
            Number of times the cmdlet will wait, when ITGlue responds with 'rate limit reached'.
        .PARAMETER ItGlueUriBase
            Base URL for the ITGlue API.
        .PARAMETER ItGluePageSize
            Page size when requesting ITGlue resources via the API. Note that retrieving flexible asset instances is computationally expensive, which may cause a timeout. When that happens, drop the page size down (a lot).
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -ItGlueApiKey ITG.XXXXXXXXXXXXX -FlexibleAssetId 123456

            In this example, the cmdlet will get all instances of flexible asset type 123456, using the provided ITGlue API key. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -FlexibleAssetId 123456 -ItGlueUserCred (Get-Credential) -BlockLogging -Verbose

            In this example, the cmdlet will get all instances of the flexible asset type 123456, using the provided ITGlue user credentials. Output will only be sent to the host session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ITGlueApiKey')]
    param (
        [Parameter(ParameterSetName = 'ITGlueApiKey', Mandatory)]
        [SecureString]$ItGlueApiKey,

        [Parameter(ParameterSetName = 'ITGlueUserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$ItGlueUserCred,

        [Parameter(Mandatory = $True)]
        $FlexibleAssetId,

        [int]$MaxLoopCount = 5,

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
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

    $message = ("{0}: Operating in the {1} parameterset." -f (Get-Date -Format s), $PsCmdlet.ParameterSetName)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

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

    $message = ("Attempting to retrieve all the requested flexible assets from ITGlue.")
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

    $loopCount = 0
    Do {
        Try {
            $loopCount++

            $allExistingAssetInstances = Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/flexible_assets?page[size]=$ItGluePageSize" -Body (@{"filter[flexible_asset_type_id]" = "$FlexibleAssetId" }) -ErrorAction Stop

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

    $loopCount = 0
    $stopLoop = $false
    $allExistingAssetInstances = for ($i = 1; $i -le $($allExistingAssetInstances.meta.'total-pages'); $i++) {
        $adQueryBody = @{
            "page[size]"                     = $ItGluePageSize
            "page[number]"                   = $i
            #"filter[organization_id]"        = "$ItGlueCustomerId" #This line can come out eventually. I just don't want to remove it yet. It is not required for this function (obviously).
            "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
        }

        $message = ("Getting page {0} of {1} of the requested flexible assets." -f $i, $($allExistingAssetInstances.meta.'total-pages'))
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

        Do {
            Try {
                $loopCount++

                (Invoke-RestMethod -Method GET -Headers $ItGlueApiHeader -Uri "$ItGlueUriBase/flexible_assets" -Body $adQueryBody -ErrorAction Stop).data

                $stopLoop = $True
            }
            Catch {
                If ($loopCount -ge $MaxLoopCount) {
                    $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                    If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
                If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    #$ItGluePageSize = $ItGluePageSize / 2

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

    Return $allExistingAssetInstances
} #1.0.0.5
Function Get-ItGlueJsonWebToken {
    <#
        .DESCRIPTION
            Accept a PowerShell credential object and use it to generate a JSON web token for authentication to the ITGlue API.
        .NOTES
            V1.0.0.0 date: 28 February 2019
                - Initial release.
            V1.0.0.1 date: 2 April 2019
                - Updated in-line documentation.
        .PARAMETER Credential
            ITGlue credential object for the desired local account.
        .PARAMETER ItGlueUriBase
            Base URL for the ITGlue customer.
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Get-ItGlueJsonWebToken -Credential (Get-Credential) -ItGlueUriBase https://company.itglue.com

            In this example, the cmdlet connects to https://company.itglue.com and generates an access token for the user specified in Get-Credential. Output will be sent to the host session and to the Windows event log.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $True)]
        [ValidatePattern("^https?:\/\/[a-zA-Z0-9]+\.itglue\.com$")]
        [string]$ItGlueUriBase,

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
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

    # Initialize variables.
    $ItGlueUriBase = $ItGlueUriBase.TrimEnd('/')

    $message = ("{0}: Step 1, get a refresh token." -f (Get-Date -Format s))
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

    # Get ITGlue refresh token.
    $attributes = New-Object PSObject
    $attributes | Add-Member -Type NoteProperty -Name "email" -Value $Credential.UserName
    $attributes | Add-Member -Type NoteProperty -Name "password" -Value $Credential.GetNetworkCredential().password

    $user = New-Object PSObject
    $user | Add-Member -Type NoteProperty -Name "user" -Value $attributes

    $url = "$ItGlueUriBase/login?generate_jwt=1&sso_disabled=1"
    $headers = @{}
    $headers.add('cache-control', 'no-cache')
    $headers.add('content-type', 'application/json')

    Try {
        $refreshToken = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -Body ($user | ConvertTo-Json) -Method POST -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error getting a refresh token. To prevent errors, {1} will exit. The specific error is: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
        If ($BlockLogging) {Write-Error $message} Else {Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417}

        Return
    }

    $message = ("{0}: Step 2, get an access token." -f (Get-Date -Format s))
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) {Write-Verbose $message} ElseIf ($PSBoundParameters['Verbose']) {Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417}

    # Get ITGlue access token.
    $url = "$ItGlueUriBase/jwt/token?refresh_token=$(($refreshToken.Content | ConvertFrom-Json).token)"
    $headers = @{}
    $headers.add('cache-control', 'no-cache')

    Try {
        $accessToken = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -Method GET -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error getting a refresh token. To prevent errors, {1} will exit. The specific error is: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
        If ($BlockLogging) {Write-Error $message} Else {Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417}

        Return
    }

    Return $accessToken
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
        .PARAMETER CustomerName
            Enter the name of the desired customer, or "All" to retrieve all organizations.
        .PARAMETER CustomerId
            Desired customer's ITGlue organization ID.
        .PARAMETER ItGlueApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER ItGlueUserCred
            ITGlue credential object for the desired local account.
        .PARAMETER MaxLoopCount
            Number of times the cmdlet will wait, when ITGlue responds with 'rate limit reached'.
        .PARAMETER ItGlueUriBase
            Base URL for the ITGlue API.
        .PARAMETER ItGluePageSize
            Page size when requesting ITGlue resources via the API.
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -ItGlueApiKey ITG.XXXXXXXXXXXXX -CustomerName All

            In this example, the cmdlet will get all of the organzations in the instance. Output is sent to the host session and event log.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -ItGlueUserCred (Get-Credential) -ComputerName company1 -BlockLogging -Verbose

            In this example, the cmdlet will get all of the organzations in the instance, with the name "company1". Output will only be sent to the host session.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -ItGlueUserCred (Get-Credential) -CustomerId 123456 -BlockLogging -Verbose

            In this example, the cmdlet will get the customer with ID 123456, using the provided ITGlue user credentials. Output will only be sent to the host session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ITGlueApiKey')]
    param (
        [ValidatePattern("^All$|^[a-z,A-Z,0-9]+")]
        [string]$CustomerName,

        [int64]$CustomerId,

        [Parameter(ParameterSetName = 'ITGlueApiKey', Mandatory)]
        [SecureString]$ItGlueApiKey,

        [Parameter(ParameterSetName = 'ITGlueUserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$ItGlueUserCred,

        [int]$MaxLoopCount = 5,

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
    If ($ItGlueApiKey) {
        $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ItGlueApiKey)); "content-type" = "application/vnd.api+json"; }
    }
    Else {
        $accessToken = Get-ItGlueJsonWebToken -Credential $ItGlueUserCred

        $ItGlueUriBase = 'https://api-mobile-prod.itglue.com/api'
        $header = @{ }
        $header.add('cache-control', 'no-cache')
        $header.add('content-type', 'application/vnd.api+json')
        $header.add('authorization', "Bearer $(($accessToken.Content | ConvertFrom-Json).token)")

    }

    If ($CustomerName -eq "All") {
        $message = ("{0}: Getting all organizations." -f (Get-Date -Format s))
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        # Get all ITGlue organizations.
        $loopCount = 0
        Do {
            Try {
                $loopCount++

                $allOrgCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$ItGlueUriBase/organizations?page[size]=$ItGluePageSize" -ErrorAction Stop

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
                    $message = ("{0}: Unexpected error getting organizations. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        $loopCount = 0
        $stopLoop = $false
        $organizations = for ($i = 1; $i -le $($allOrgCount.meta.'total-pages'); $i++) {
            $orgQueryBody = @{
                "page[size]"   = $ItGluePageSize
                "page[number]" = $i
            }

            $message = ("{0}: Getting page {1} of {2} of organization." -f (Get-Date -Format s), $i, $allOrgCount.meta.'total-pages')
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $loopCount = 0
            $stopLoop = $false
            Do {
                Try {
                    $loopCount++

                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$ItGlueUriBase/organizations" -Body $orgQueryBody -ErrorAction Stop).data
                }
                Catch {
                    If ($loopCount -ge $MaxLoopCount) {
                        $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {

                        $message = ("{0}: Rate limit exceeded, retrying in 60 seconds with `$ITGluePageSize == {1}." -f (Get-Date -Format s), $ItGluePageSize)
                        If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Warning -Message $message -EventId 5417 }

                        Start-Sleep -Seconds 60
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting organizations. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

        }

        $message = ("{0}: Found {1} organizations." -f (Get-Date -Format s), $organizations.count)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        Return $organizations
    }
    ElseIf ($CustomerName) {
        $message = ("{0}: Getting all organizations." -f (Get-Date -Format s))
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        # Get all ITGlue organizations.
        $loopCount = 0
        Do {
            Try {
                $loopCount++

                $allOrgCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$ItGlueUriBase/organizations?page[size]=$ItGluePageSize" -ErrorAction Stop

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
                    $message = ("{0}: Unexpected error getting organizations. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        $loopCount = 0
        $stopLoop = $false
        $organizations = for ($i = 1; $i -le $($allOrgCount.meta.'total-pages'); $i++) {
            $orgQueryBody = @{
                "page[size]"   = $ItGluePageSize
                "page[number]" = $i
            }

            $message = ("{0}: Getting page {1} of {2} of organization." -f (Get-Date -Format s), $i, $allOrgCount.meta.'total-pages')
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $loopCount = 0
            Do {
                Try {
                    $loopCount++

                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$ItGlueUriBase/organizations" -Body $orgQueryBody -ErrorAction Stop).data
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
                        $message = ("{0}: Unexpected error getting organizations. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)
        }

        $message = ("{0}: Found {1} organizations, filtering for {2}." -f (Get-Date -Format s), $organizations.count, $CustomerName)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $organizations = $organizations | Where-Object { $_.attributes.name -eq $CustomerName }

        Return $organizations
    }
    ElseIf ($CustomerId) {
        $message = ("Getting organization with ID." -f $CustomerId)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $loopCount = 0
        $stopLoop = $false
        Do {
            Try {
                $loopCount++

                ($organizations = Invoke-RestMethod -Method GET -Headers $header -Uri "$ItGlueUriBase/organizations/$CustomerId" -ErrorAction Stop).data

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
                    $message = ("{0}: Unexpected error getting organizations. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        Return $organizations
    }
} #1.0.0.2
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
        .PARAMETER Data
            Custom PSObject containing flexible asset properties.
        .PARAMETER HttpMethod
            Used to dictate whether the cmdlet should use POST or PATCH when sending data to ITGlue.
        .PARAMETER FlexibleAssetInstanceId
            When included, is used to update (PATCH) a specifc instance of a flexible asset.
        .PARAMETER ItGlueApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER ItGlueUserCred
            ITGlue credential object for the desired local account.
        .PARAMETER MaxLoopCount
            Number of times the cmdlet will wait, when ITGlue responds with 'rate limit reached'.
        .PARAMETER ItGlueUriBase
            Base URL for the ITGlue API.
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod POST -ItGlueApiKey ITG.XXXXXXXXXXXXX

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new flexible asset, using the provided ITGlue API key. The cmdlet will try uploading 5 times. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod POST -ItGlueApiKey ITG.XXXXXXXXXXXXX -MaxLoopCount 10

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new flexible asset, using the provided ITGlue API key. The cmdlet will try uploading 10 times. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod PATCH -FlexibleAssetInstanceId 123456 -ItGlueUserCred (Get-Credential) -BlockLogging -Verbose

            In this example, the cmdlet will convert the contents of $uploadData to JSON and update the flexible asset with ID 123456, using the provided ITGlue user credentials. Output will only be sent to the host session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ITGlueApiKey')]
    param (
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$Data,

        [Parameter(Mandatory = $True)]
        [ValidateSet('POST', 'PATCH')]
        [string]$HttpMethod,

        [int64]$FlexibleAssetInstanceId,

        [Parameter(ParameterSetName = 'ITGlueApiKey', Mandatory)]
        [SecureString]$ItGlueApiKey,

        [Parameter(ParameterSetName = 'ITGlueUserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$ItGlueUserCred,

        [int]$MaxLoopCount = 5,

        [string]$ItGlueUriBase = "https://api.itglue.com",

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

    # Initialize variables.
    $HttpMethod = $HttpMethod.ToUpper()
    $loopCount = 0
    $stopLoop = $false

    $message = ("{0}: Beginning {1}." -f (Get-Date -Format s), $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # We are patching, but don't have a flexible asset instance to patch, request the ID.
    If (($HttpMethod -eq 'PATCH') -and (-NOT($FlexibleAssetInstanceId))) {
        $FlexibleAssetInstanceId = Read-Host -Message "Enter a flexible asset instance ID"
    }

    $message = ("{0}: Operating in the {1} parameterset." -f (Get-Date -Format s), $PsCmdlet.ParameterSetName)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Initialize variables.
    Switch ($PsCmdlet.ParameterSetName) {
        'ITGlueApiKey' {
            $message = ("{0}: Setting header with API key." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ItGlueApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'ITGlueUserCred' {
            $message = ("{0}: Setting header with user-access token." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $accessToken = Get-ItGlueJsonWebToken -Credential $ItGlueUserCred

            $ItGlueUriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ }
            $header.add('cache-control', 'no-cache')
            $header.add('content-type', 'application/vnd.api+json')
            $header.add('authorization', "Bearer $(($accessToken.Content | ConvertFrom-Json).token)")
        }
    }

    # Upload data to ITGlue.
    If ($HttpMethod -eq 'PATCH') {
        $message = ("{0}: Preparing URL {1}." -f (Get-Date -Format s), "$ItGlueUriBase/flexible_assets/$FlexibleAssetInstanceId")
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $uploadUrl = "$ItGlueUriBase/flexible_assets/$FlexibleAssetInstanceId"
    }
    Else {
        $message = ("{0}: Preparing URL {1}." -f (Get-Date -Format s), "$ItGlueUriBase/flexible_assets")
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $uploadUrl = "$ItGlueUriBase/flexible_assets"
    }

    $message = ("{0}: Attempting to uplaod data to ITGlue (method: {1})" -f (Get-Date -Format s), $HttpMethod)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    Do {
        Try {
            $loopCount++

            Invoke-RestMethod -Method $HttpMethod -Headers $header -Uri $uploadUrl -Body ($Data | ConvertTo-Json -Depth 10) -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
            If ($loopCount -ge $MaxLoopCount) {
                $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
            If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty message -ErrorAction SilentlyContinue) -eq "Endpoint request timed out") {
                $ItGluePageSize = $ItGluePageSize / 2

                $message = ("{0}: Rate limit exceeded, retrying in 60 seconds with `$ITGluePageSize == {1}." -f (Get-Date -Format s), $ItGluePageSize)
                If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                Start-Sleep -Seconds 60
            }
            Else {
                $message = ("{0}: Unexpected error uploading flexible asset. To prevent errors, {1} will exit. PowerShell returned: {2}" -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)
} #1.0.0.7
Function Remove-ItGlueFlexibleAssetInstance {
    <#
        .DESCRIPTION
            
        .NOTES
            V1.0.0.0 date: 11 April 2019
                - Initial release.
            V1.0.0.1 date: 24 April 2019
                - Added $MaxLoopCount parameter.
            V1.0.0.2 date: 20 May 2019
                - Updated rate-limit detection.
        .PARAMETER ItGlueApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER ItGlueUserCred
            ITGlue credential object for the desired local account.
        .PARAMETER Id
            Identifier ID for the desired flexible asset type.
        .PARAMETER MaxLoopCount
            Number of times the cmdlet will wait, when ITGlue responds with 'rate limit reached'.
        .PARAMETER ItGlueUriBase
            Base URL for the ITGlue API.
        .PARAMETER ItGluePageSize
            Page size when requesting ITGlue resources via the API. Note that retrieving flexible asset instances is computationally expensive, which may cause a timeout. When that happens, drop the page size down (a lot).
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Remove-ItGlueFlexibleAssetInstance -ItGlueApiKey ITG.XXXXXXXXXXXXX -Id 123456

            In this example, the cmdlet will remove the flexible asset with ID 123456, using the provided ITGlue API key. Output is written to the session host and the Windows event log.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -FlexibleAssetId 123456 -ItGlueUserCred (Get-Credential) -BlockLogging -Verbose

            In this example, the cmdlet will remove the flexible asset with ID 123456, using the provided ITGlue credentials. Output is written to the session host only
    #>
    [CmdletBinding(DefaultParameterSetName = 'ITGlueApiKey')]
    param (
        [Parameter(ParameterSetName = 'ITGlueApiKey', Mandatory)]
        [SecureString]$ItGlueApiKey,

        [Parameter(ParameterSetName = 'ITGlueUserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$ItGlueUserCred,

        [Parameter(Mandatory = $True, ValueFromPipeline)]
        $Id,

        [int]$MaxLoopCount = 5,

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
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

    $message = ("{0}: Operating in the {1} parameterset." -f (Get-Date -Format s), $PsCmdlet.ParameterSetName)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Initialize variables.
    $stopLoop = $false
    $httpVerb = 'DELETE'
    Switch ($PsCmdlet.ParameterSetName) {
        'ITGlueApiKey' {
            $message = ("{0}: Setting header with API key." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ItGlueApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'ITGlueUserCred' {
            $message = ("{0}: Setting header with user-access token." -f (Get-Date -Format s))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

            $accessToken = Get-ItGlueJsonWebToken -Credential $ItGlueUserCred

            $ItGlueUriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ }
            $header.add('cache-control', 'no-cache')
            $header.add('content-type', 'application/vnd.api+json')
            $header.add('authorization', "Bearer $(($accessToken.Content | ConvertFrom-Json).token)")
        }
    }

    $message = ("{0}: Attempting to delete the flexible asset with instance: {1}." -f (Get-Date -Format s), $Id)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Information -Message $message -EventId 5417 }

    $loopCount = 0
    Do {
        Try {
            $loopCount++

            $response = Invoke-RestMethod -Method $httpVerb -Headers $header -Uri "$ItGlueUriBase/flexible_assets/$Id" -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
            If ($loopCount -ge $MaxLoopCount) {
                $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
            If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty message) -eq "Endpoint request timed out") {
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

    Return $response
} #1.0.0.2
Export-ModuleMember -Alias * -Function *
