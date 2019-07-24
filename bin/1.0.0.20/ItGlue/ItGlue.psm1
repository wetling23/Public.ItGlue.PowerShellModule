Function Get-ItGlueDeviceConfig {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or more device configs.
        .NOTES
            V1.0.0.4 date: 2 July 2019
            V1.0.0.5 date: 11 July 2019
            V1.0.0.6 date: 12 July 2019
            V1.0.0.7 date: 18 July 2019
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ComputerName
            Enter the hostname of the desired device config, or "All" to retrieve all device configs.
        .PARAMETER CustomerId
            Desired customer's ITGlue organization ID.
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER PageSize
            Page size when requesting ITGlue resources via the API.
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -ApiKey ITG.XXXXXXXXXXXXX -ComputerName All

            In this example, the cmdlet will get all ITGlue device configurations, using the provided ITGlue API key. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -UserCred (Get-Credential) -ComputerName server1 -BlockLogging -Verbose

            In this example, the cmdlet will get all device configurations for "server1", using the provided ITGlue user credentials. Output will only be sent to the host session.
        .EXAMPLE
            PS C:\> Get-ItGlueDeviceConfig -UserCred (Get-Credential) -ItGlueCustomerId 123456 -BlockLogging -Verbose

            In this example, the cmdlet will get all device configurations for customer with ID 123456, using the provided ITGlue user credentials. Output will only be sent to the host session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [ValidatePattern("^All$|^[a-z,A-Z,0-9]+")]
        [string]$ComputerName,

        [Alias("ItGlueCustomerId")]
        [int64]$CustomerId,

        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

        [Alias("ItGlueUriBase")]
        [string]$UriBase = "https://api.itglue.com",

        [Alias("ItGluePageSize")]
        [int64]$PageSize = 1000,

        [string]$EventLogSource = 'ItGluePowerShellModule',

        [switch]$BlockLogging
    )

    If (-NOT($BlockLogging)) {
        $return = Add-EventLogSource -EventLogSource $EventLogSource

        If ($return -ne "Success") {
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f [datetime]::Now, $EventLogSource)
            Write-Verbose $message

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Initialize variables.
    $retrievedInstanceCollection = [System.Collections.Generic.List[PSObject]]::New()
    $onlyOneInstance = $false
    $stopLoop = $false
    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f [datetime]::Now)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f [datetime]::Now)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    If (-NOT(($ComputerName) -or ($CustomerId))) {
        $message = ("{0}: No computer name or customer ID supplied. Please supply a value for one or both parameters." -f [datetime]::Now, $MyInvocation.MyCommand)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

        Return "Error"
    }

    If ($ComputerName -eq "All") {
        $message = ("{0}: Getting all devices configurations." -f [datetime]::Now)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        Do {
            Try {
                $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=$PageSize" -ErrorAction Stop

                $stopLoop = $True
            }
            Catch {
                If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    $PageSize = $PageSize / 2

                    If ($PageSize -lt 1) {
                        $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }

                    $message = ("{0}: Request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                    If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                    Start-Sleep -Seconds 5
                }
                Else {
                    $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        $page = 1
        Do {
            $stopLoop = $False
            $queryBody = @{
                "page[size]"   = $PageSize
                "page[number]" = $page
            }

            $message = ("Retrieved {0} of {1} instances." -f $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                        $PageSize = [math]::Round($PageSize / 2)
                        $queryBody = @{
                            "page[size]"   = $PageSize
                            "page[number]" = $page
                        }

                        If ($PageSize -lt 1) {
                            $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
                            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }

                        $message = ("{0}: The request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                        If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                        Start-Sleep -Seconds 5
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++
        }
        While ($retrievedInstanceCollection.data.Count -ne $instancePageCount.meta.'total-count')

        $message = ("{0}: Found {1} device configurations." -f [datetime]::Now, $retrievedInstanceCollection.data.count)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        Return $retrievedInstanceCollection.data
    }
    Else {
        If ($CustomerId) {
            $message = ("Getting devices for customer with ID {0}." -f $CustomerId)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            Do {
                Try {
                    $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=$PageSize&filter[organization-id]=$CustomerId" -ErrorAction Stop

                    $stopLoop = $True
                }
                Catch {
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                        $PageSize = [math]::Round($PageSize / 2)

                        If ($PageSize -lt 1) {
                            $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
                            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }

                        $message = ("{0}: The request timed out, retrying in 5 seconds with `$PageSize == {1}. New `$totalPages == {2}" -f [datetime]::Now, $PageSize, $totalPages)
                        If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                        Start-Sleep -Seconds 5
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page = 1
            Do {
                $stopLoop = $False
                $queryBody = @{
                    "page[size]"              = $PageSize
                    "page[number]"            = $page
                    "filter[organization-id]" = $CustomerId
                }

                $message = ("Retrieved {0} of {1} instances." -f $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

                Do {
                    Try {
                        (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                        $stopLoop = $True
                    }
                    Catch {
                        If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                            $PageSize = [math]::Round($PageSize / 2)

                            If ($PageSize -lt 1) {
                                $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
                                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                                Return "Error"
                            }

                            $message = ("{0}: The request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                            If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                            Start-Sleep -Seconds 5
                        }
                        Else {
                            $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                    [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }
                    }
                }
                While ($stopLoop -eq $false)

                $page++

                If (($instancePageCount.meta.'total-count' -eq 1) -and ($retrievedInstanceCollection)) {
                    $message = ("There is only one instance, getting ready to return it.")
                    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

                    $onlyOneInstance = $true
                }
            }
            While (($retrievedInstanceCollection.data.Count -ne $instancePageCount.meta.'total-count') -and ($onlyOneInstance -eq $false))

            If ($ComputerName) {

                $message = ("Returning devices matching {0} at {1}." -f $ComputerName, $CustomerId)
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

                Return ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -match $ComputerName })
            }
            Else {
                $message = ("Returning devices at {0}." -f $CustomerId)
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

                Return $retrievedInstanceCollection.data
            }
        }
        Else {
            $message = ("{0}: Getting all devices configurations with the hostname matching {1}." -f [datetime]::Now, $ComputerName)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $stopLoop = $false
            Do {
                Try {
                    $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations?page[size]=$PageSize" -ErrorAction Stop

                    $stopLoop = $True
                }
                Catch {
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                        $PageSize = $PageSize / 2

                        If ($PageSize -lt 1) {
                            $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand)
                            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }

                        $message = ("{0}: Request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                        If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                        Start-Sleep -Seconds 5
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page = 1
            Do {
                $stopLoop = $False
                $queryBody = @{
                    "page[size]"   = $PageSize
                    "page[number]" = $page
                }

                $message = ("Retrieved {0} of {1} instances." -f $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
                If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

                Do {
                    Try {
                        (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/configurations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                        $stopLoop = $True
                    }
                    Catch {
                        If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                            $PageSize = [math]::Round($PageSize / 2)

                            If ($PageSize -lt 1) {
                                $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand)
                                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                                Return "Error"
                            }

                            $message = ("{0}: The request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                            If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                            Start-Sleep -Seconds 5
                        }
                        Else {
                            $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                    [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }
                    }
                }
                While ($stopLoop -eq $false)

                $page++

                If (($instancePageCount.meta.'total-count' -eq 1) -and ($retrievedInstanceCollection)) {
                    $message = ("There is only one instance, getting ready to return it.")
                    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

                    $onlyOneInstance = $true
                }
            }
            While (($retrievedInstanceCollection.data.Count -ne $instancePageCount.meta.'total-count') -and ($onlyOneInstance -eq $false))

            $message = ("{0}: Found {1} device configurations." -f [datetime]::Now, $retrievedInstanceCollection.data.Count)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $message = ("Returning devices matching {0}." -f $ComputerName)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            Return ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -match $ComputerName })
        }
    }
} #1.0.0.7
Function Get-ItGlueFlexibleAssetInstance {
    <#
        .DESCRIPTION
            Gets all instances of a flexible asset, based on the ID.
        .NOTES
            V1.0.0.8 date: 2 July 2019
            V1.0.0.9 date: 11 July 2019
            V1.0.0.10 date: 18 July 2019
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER FlexibleAssetId
            Identifier ID for the desired flexible asset type.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER PageSize
            Page size when requesting ITGlue resources via the API. Note that retrieving flexible asset instances is computationally expensive, which may cause a timeout. When that happens, drop the page size down (a lot).
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -ApiKey ITG.XXXXXXXXXXXXX -FlexibleAssetId 123456

            In this example, the cmdlet will get all instances of flexible asset type 123456, using the provided ITGlue API key. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -FlexibleAssetId 123456 -Credential (Get-Credential) -BlockLogging -Verbose

            In this example, the cmdlet will get all instances of the flexible asset type 123456, using the provided ITGlue user credentials. Output will only be sent to the host session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory = $True)]
        $FlexibleAssetId,

        [Alias("ItGlueUriBase")]
        [string]$UriBase = "https://api.itglue.com",

        [Alias("ItGluePageSize")]
        [int64]$PageSize = 1000,

        [string]$EventLogSource = 'ItGluePowerShellModule',

        [switch]$BlockLogging
    )

    If (-NOT($BlockLogging)) {
        $return = Add-EventLogSource -EventLogSource $EventLogSource

        If ($return -ne "Success") {
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f [datetime]::Now, $EventLogSource)
            Write-Verbose $message

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    $message = ("{0}: Operating in the {1} parameterset." -f [datetime]::Now, $PsCmdlet.ParameterSetName)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Initialize variables.
    $retrievedInstanceCollection = [System.Collections.Generic.List[PSObject]]::New()
    $stopLoop = $false
    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f [datetime]::Now)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f [datetime]::Now)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $accessToken = Get-ItGlueJsonWebToken -Credential $Credential

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    $message = ("Attempting to determine how many instances there are.")
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    Do {
        Try {
            $instanceTotalCount = Invoke-webrequest -Method GET -Headers $header -Uri "$UriBase/flexible_assets?page[size]=$PageSize" -Body (@{"filter[flexible_asset_type_id]" = "$FlexibleAssetId" }) -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
            If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                $PageSize = $PageSize / 2

                If ($PageSize -lt 1) {
                    $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }

                $message = ("{0}: Request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                Start-Sleep -Seconds 5
            }
            Else {
                $message = ("{0}: Unexpected error getting device configurations assets. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                        [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)

    $page = 1
    Do {
        $stopLoop = $False
        $queryBody = @{
            "page[size]"                     = $PageSize
            "page[number]"                   = $page
            "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
        }

        $message = ("Retrieved {0} of {1} instances." -f $retrievedInstanceCollection.Count, $($instanceTotalCount.meta.'total-count'))
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        Do {
            Try {
                (Invoke-webrequest -Method GET -Headers $header -Uri "$UriBase/flexible_assets" -Body $queryBody -ErrorAction Stop).data | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                $stopLoop = $True
            }
            Catch {
                If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    $PageSize = [math]::Round($PageSize / 2)
                    $queryBody = @{
                        "page[size]"                     = $PageSize
                        "page[number]"                   = $page
                        "filter[flexible_asset_type_id]" = "$FlexibleAssetId"
                    }

                    If ($PageSize -lt 1) {
                        $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }

                    $message = ("{0}: The request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                    If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                    Start-Sleep -Seconds 5
                }
                Else {
                    $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        $page++
    }
    While ($retrievedInstanceCollection.Count -ne $instanceTotalCount.meta.'total-count')

    Return $retrievedInstanceCollection
} #1.0.0.10
Function Get-ItGlueJsonWebToken {
    <#
        .DESCRIPTION
            Accept a PowerShell credential object and use it to generate a JSON web token for authentication to the ITGlue API.
        .NOTES
            V1.0.0.0 date: 28 February 2019
                - Initial release.
            V1.0.0.1 date: 2 April 2019
                - Updated in-line documentation.
            V1.0.0.2 date: 24 May 2019
                - Updated formatting.
                - Updated date calculation.
            V1.0.0.3 date: 18 July 2019
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
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f [datetime]::Now, $EventLogSource)
            Write-Verbose $message

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Initialize variables.
    $ItGlueUriBase = $ItGlueUriBase.TrimEnd('/')

    $message = ("{0}: Step 1, get a refresh token." -f [datetime]::Now)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Get ITGlue refresh token.
    $attributes = New-Object PSObject
    $attributes | Add-Member -Type NoteProperty -Name "email" -Value $Credential.UserName
    $attributes | Add-Member -Type NoteProperty -Name "password" -Value $Credential.GetNetworkCredential().password

    $user = New-Object PSObject
    $user | Add-Member -Type NoteProperty -Name "user" -Value $attributes

    $url = "$ItGlueUriBase/login?generate_jwt=1&sso_disabled=1"
    $headers = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/json' }

    Try {
        $refreshToken = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -Body ($user | ConvertTo-Json) -Method POST -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error getting a refresh token. To prevent errors, {1} will exit. The specific error is: {2}" -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

        Return
    }

    $message = ("{0}: Step 2, get an access token." -f [datetime]::Now)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Get ITGlue access token.
    $url = "$ItGlueUriBase/jwt/token?refresh_token=$(($refreshToken.Content | ConvertFrom-Json).token)"
    $headers = @{ }
    $headers.add('cache-control', 'no-cache')

    Try {
        $accessToken = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $headers -Method GET -ErrorAction Stop
    }
    Catch {
        $message = ("{0}: Unexpected error getting a refresh token. To prevent errors, {1} will exit. The specific error is: {2}" -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

        Return
    }

    Return $accessToken
} #1.0.0.3
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
            V1.0.0.3 date: 24 May 2019
                - Updated formatting.
                - Updated date calculation.
            V1.0.0.4 date: 31 May 2019
                - Updated log verbiage.
                - Fixed bug in loop incrementing.
            V1.0.0.5 date: 11 July 2019
            V1.0.0.6 date: 18 July 2019
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER CustomerName
            Enter the name of the desired customer, or "All" to retrieve all organizations.
        .PARAMETER CustomerId
            Desired customer's ITGlue organization ID.
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER PageSize
            Page size when requesting ITGlue resources via the API.
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -ItGlueApiKey ITG.XXXXXXXXXXXXX -CustomerName All

            In this example, the cmdlet will get all of the organzations in the instance. Output is sent to the host session and event log.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -UserCred (Get-Credential) -ComputerName company1 -BlockLogging -Verbose

            In this example, the cmdlet will get all of the organzations in the instance, with the name "company1". Output will only be sent to the host session.
        .EXAMPLE
            PS C:\> Get-ItGlueOrganization -UserCred (Get-Credential) -CustomerId 123456 -BlockLogging -Verbose

            In this example, the cmdlet will get the customer with ID 123456, using the provided ITGlue user credentials. Output will only be sent to the host session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [ValidatePattern("^All$|^[a-z,A-Z,0-9]+")]
        [string]$CustomerName,

        [Alias("ItGlueCustomerId")]
        [int64]$CustomerId,

        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

        [Alias("ItGlueUriBase")]
        [string]$UriBase = "https://api.itglue.com",

        [Alias("ItGluePageSize")]
        [int64]$PageSize = 1000,

        [string]$EventLogSource = 'ItGluePowerShellModule',

        [switch]$BlockLogging
    )

    If (-NOT($BlockLogging)) {
        $return = Add-EventLogSource -EventLogSource $EventLogSource

        If ($return -ne "Success") {
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f [datetime]::Now, $EventLogSource)
            Write-Verbose $message

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Initialize variables.
    $retrievedInstanceCollection = [System.Collections.Generic.List[PSObject]]::New()
    $stopLoop = $false
    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f [datetime]::Now)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f [datetime]::Now)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred

            $UriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    If (-NOT(($CustomerName) -or ($CustomerId))) {
        $message = ("{0}: No customer name or ID supplied. Defaulting to retrieving all organizations." -f [datetime]::Now, $MyInvocation.MyCommand)
        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

        $CustomerName = "All"
    }

    If ($CustomerName -eq "All") {
        $message = ("{0}: Getting all organizations." -f [datetime]::Now)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        Do {
            Try {
                $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations?page[size]=$PageSize" -ErrorAction Stop

                $stopLoop = $True
            }
            Catch {
                If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    $PageSize = $PageSize / 2

                    If ($PageSize -lt 1) {
                        $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }

                    $message = ("{0}: Request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                    If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                    Start-Sleep -Seconds 5
                }
                Else {
                    $message = ("{0}: Unexpected error getting organizations. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        $page = 1
        Do {
            $stopLoop = $False
            $queryBody = @{
                "page[size]"   = $PageSize
                "page[number]" = $page
            }

            $message = ("Retrieved {0} of {1} instances." -f $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                        $PageSize = [math]::Round($PageSize / 2)
                        $queryBody = @{
                            "page[size]"   = $PageSize
                            "page[number]" = $page
                        }

                        If ($PageSize -lt 1) {
                            $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
                            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }

                        $message = ("{0}: The request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                        If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                        Start-Sleep -Seconds 5
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++
        }
        While ($retrievedInstanceCollection.data.Count -ne $instancePageCount.meta.'total-count')

        $message = ("{0}: Found {1} organizations." -f [datetime]::Now, $retrievedInstanceCollection.data.count)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        Return $retrievedInstanceCollection.data
    }
    ElseIf ($CustomerName) {
        $message = ("{0}: Getting {1}." -f [datetime]::Now, $CustomerName)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        Do {
            Try {
                $instancePageCount = Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations?page[size]=$PageSize" -ErrorAction Stop

                $stopLoop = $True
            }
            Catch {
                If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    $PageSize = $PageSize / 2

                    If ($PageSize -lt 1) {
                        $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }

                    $message = ("{0}: Request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                    If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                    Start-Sleep -Seconds 5
                }
                Else {
                    $message = ("{0}: Unexpected error getting organizations. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        $page = 1
        Do {
            $stopLoop = $False
            $queryBody = @{
                "page[size]"   = $PageSize
                "page[number]" = $page
            }

            $message = ("Retrieved {0} of {1} instances." -f $retrievedInstanceCollection.data.Count, $($instancePageCount.meta.'total-count'))
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            Do {
                Try {
                    (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations" -Body $queryBody -ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                    $stopLoop = $True
                }
                Catch {
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                        $PageSize = [math]::Round($PageSize / 2)
                        $queryBody = @{
                            "page[size]"   = $PageSize
                            "page[number]" = $page
                        }

                        If ($PageSize -lt 1) {
                            $message = ("{0}: Page size is less than 1, {1} will exit." -f [datetime]::Now, $MyInvocation.MyCommand, $_.Exception.Message)
                            If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                            Return "Error"
                        }

                        $message = ("{0}: The request timed out, retrying in 5 seconds with `$PageSize == {1}." -f [datetime]::Now, $PageSize)
                        If ($BlockLogging) { Write-Warning $message } Else { Write-Warning $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Warning -Message $message -EventId 5417 }

                        Start-Sleep -Seconds 5
                    }
                    Else {
                        $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                                [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                        If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                }
            }
            While ($stopLoop -eq $false)

            $page++
        }
        While ($retrievedInstanceCollection.data.Count -ne $instancePageCount.meta.'total-count')

        $message = ("{0}: Found {1} organizations, filtering for {2}." -f [datetime]::Now, $retrievedInstanceCollection.data.Count, $CustomerName)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        Return = ($retrievedInstanceCollection.data | Where-Object { $_.attributes.name -eq $CustomerName })
    }
    ElseIf ($CustomerId) {
        $message = ("Getting organization with ID." -f $CustomerId)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $stopLoop = $false
        Do {
            Try {
                (Invoke-RestMethod -Method GET -Headers $header -Uri "$UriBase/organizations/$CustomerId"-ErrorAction Stop) | ForEach-Object { $retrievedInstanceCollection.Add($_) }

                $stopLoop = $True
            }
            Catch {
                If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                    $message = ("{0}: The request for {1} timed out. {2} will exit." -f [datetime]::Now, $CustomerId, $MyInvocation.MyCommand)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
                Else {
                    $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                            [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                    If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
            }
        }
        While ($stopLoop -eq $false)

        Return $retrievedInstanceCollection
    }
} #1.0.0.6
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
            V1.0.0.8 date: 24 May 2019
                - Updated formatting.
                - Updated date calculation.
            V1.0.0.9 date: 11 July 2019
            V1.0.0.10 date: 18 July 2019
            V1.0.0.11 date: 24 July 2019
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER Data
            Custom PSObject containing flexible asset properties.
        .PARAMETER HttpMethod
            Used to dictate whether the cmdlet should use POST or PATCH when sending data to ITGlue.
        .PARAMETER FlexibleAssetInstanceId
            When included, is used to update (PATCH) a specifc instance of a flexible asset.
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod POST -ApiKey ITG.XXXXXXXXXXXXX

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new flexible asset, using the provided ITGlue API key. The cmdlet will try uploading 5 times. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod POST -ApiKey ITG.XXXXXXXXXXXXX -MaxLoopCount 10

            In this example, the cmdlet will convert the contents of $uploadData to JSON to a new flexible asset, using the provided ITGlue API key. The cmdlet will try uploading 10 times. Output will be sent to the host session and to the Windows event log.
        .EXAMPLE
            PS C:\> Out-ItGlueFlexibleAsset -Data $uploadData -HttpMethod PATCH -FlexibleAssetInstanceId 123456 -UserCred (Get-Credential) -BlockLogging -Verbose

            In this example, the cmdlet will convert the contents of $uploadData to JSON and update the flexible asset with ID 123456, using the provided ITGlue user credentials. Output will only be sent to the host session.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ApiKey')]
    param (
        [Parameter(Mandatory = $True)]
        [PSCustomObject]$Data,

        [Parameter(Mandatory = $True)]
        [ValidateSet('POST', 'PATCH')]
        [string]$HttpMethod,

        [int64]$FlexibleAssetInstanceId,

        [Alias("ItGlueApiKey")]
        [Parameter(ParameterSetName = 'ApiKey', Mandatory)]
        [SecureString]$ApiKey,

        [Alias("ItGlueUserCred")]
        [Parameter(ParameterSetName = 'UserCred', Mandatory)]
        [System.Management.Automation.PSCredential]$UserCred,

        [string]$ItGlueUriBase = "https://api.itglue.com",

        [string]$EventLogSource = 'ItGluePowerShellModule',

        [switch]$BlockLogging
    )

    If (-NOT($BlockLogging)) {
        $return = Add-EventLogSource -EventLogSource $EventLogSource

        If ($return -ne "Success") {
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f [datetime]::Now, $EventLogSource)
            Write-Verbose $message

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # We are patching, but don't have a flexible asset instance to patch, request the ID.
    If (($HttpMethod -eq 'PATCH') -and (-NOT($FlexibleAssetInstanceId))) {
        $FlexibleAssetInstanceId = Read-Host -Message "Enter a flexible asset instance ID"
    }

    $message = ("{0}: Operating in the {1} parameterset." -f [datetime]::Now, $PsCmdlet.ParameterSetName)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Initialize variables.
    $HttpMethod = $HttpMethod.ToUpper()
    $stopLoop = $false
    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f [datetime]::Now)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f [datetime]::Now)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred

            $ItGlueUriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    If ($HttpMethod -eq 'PATCH') {
        $message = ("{0}: Preparing URL {1}." -f [datetime]::Now, "$ItGlueUriBase/flexible_assets/$FlexibleAssetInstanceId")
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $uploadUrl = "$ItGlueUriBase/flexible_assets/$FlexibleAssetInstanceId"
    }
    Else {
        $message = ("{0}: Preparing URL {1}." -f [datetime]::Now, "$ItGlueUriBase/flexible_assets")
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $uploadUrl = "$ItGlueUriBase/flexible_assets"
    }

    $message = ("{0}: Attempting to upload data to ITGlue (method: {1})" -f [datetime]::Now, $HttpMethod)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $HttpMethod -Headers $header -Uri $uploadUrl -Body ($Data | ConvertTo-Json -Depth 10) -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
            If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                $message = ("{0}: The request for {1} timed out. {2} will exit." -f [datetime]::Now, $CustomerId, $MyInvocation.MyCommand)
                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
            Else {
                $message = ("{0}: Unexpected error uploading to ITGlue. To prevent errors, {1} will exit. If present, the error detail is: {2} PowerShell returned: {3}" -f `
                        [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)

    $response
} #1.0.0.11
Function Remove-ItGlueFlexibleAssetInstance {
    <#
        .DESCRIPTION
            Accept a flexible asset ID and delete it from ITGlue.
        .NOTES
            V1.0.0.0 date: 11 April 2019
                - Initial release.
            V1.0.0.1 date: 24 April 2019
                - Added $MaxLoopCount parameter.
            V1.0.0.2 date: 20 May 2019
                - Updated rate-limit detection.
            V1.0.0.3 date: 24 May 2019
                - Updated formatting.
                - Updated date calculation.
            V1.0.0.4 date: 11 July 2019
            V1.0.0.5 date: 18 July 2019
        .LINK
            https://github.com/wetling23/Public.ItGlue.PowerShellModule
        .PARAMETER ApiKey
            ITGlue API key used to send data to ITGlue.
        .PARAMETER UserCred
            ITGlue credential object for the desired local account.
        .PARAMETER Id
            Identifier ID for the desired flexible asset type.
        .PARAMETER UriBase
            Base URL for the ITGlue API.
        .PARAMETER EventLogSource
            Default value is "ItGluePowerShellModule" Represents the name of the desired source, for Event Log logging.
        .PARAMETER BlockLogging
            When this switch is included, the code will write output only to the host and will not attempt to write to the Event Log.
        .EXAMPLE
            PS C:\> Remove-ItGlueFlexibleAssetInstance -ApiKey ITG.XXXXXXXXXXXXX -Id 123456

            In this example, the cmdlet will remove the flexible asset with ID 123456, using the provided ITGlue API key. Output is written to the session host and the Windows event log.
        .EXAMPLE
            PS C:\> Get-ItGlueFlexibleAssetInstance -Id 123456 -UserCred (Get-Credential) -BlockLogging -Verbose

            In this example, the cmdlet will remove the flexible asset with ID 123456, using the provided ITGlue credentials. Output is written to the session host only
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

        [string]$EventLogSource = 'ItGluePowerShellModule',

        [switch]$BlockLogging
    )

    If (-NOT($BlockLogging)) {
        $return = Add-EventLogSource -EventLogSource $EventLogSource

        If ($return -ne "Success") {
            $message = ("{0}: Unable to add event source ({1}). No logging will be performed." -f [datetime]::Now, $EventLogSource)
            Write-Verbose $message

            $BlockLogging = $True
        }
    }

    $message = ("{0}: Beginning {1}." -f [datetime]::Now, $MyInvocation.MyCommand)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    $message = ("{0}: Operating in the {1} parameterset." -f [datetime]::Now, $PsCmdlet.ParameterSetName)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    # Initialize variables.
    $stopLoop = $false
    $httpVerb = 'DELETE'
    Switch ($PsCmdlet.ParameterSetName) {
        'ApiKey' {
            $message = ("{0}: Setting header with API key." -f [datetime]::Now)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $header = @{"x-api-key" = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ItGlueApiKey)); "content-type" = "application/vnd.api+json"; }
        }
        'UserCred' {
            $message = ("{0}: Setting header with user-access token." -f [datetime]::Now)
            If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

            $accessToken = Get-ItGlueJsonWebToken -Credential $UserCred

            $ItGlueUriBase = 'https://api-mobile-prod.itglue.com/api'
            $header = @{ 'cache-control' = 'no-cache'; 'content-type' = 'application/vnd.api+json'; 'authorization' = "Bearer $(($accessToken.Content | ConvertFrom-Json).token)" }
        }
    }

    $message = ("{0}: Attempting to delete the flexible asset with instance: {1}." -f [datetime]::Now, $Id)
    If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

    Do {
        Try {
            $response = Invoke-RestMethod -Method $httpVerb -Headers $header -Uri "$ItGlueUriBase/flexible_assets/$Id" -ErrorAction Stop

            $stopLoop = $True
        }
        Catch {
            If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty errors).detail -eq "The request took too long to process and timed out.") {
                $message = ("{0}: The request for {1} timed out. {2} will exit." -f [datetime]::Now, $CustomerId, $MyInvocation.MyCommand)
                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
            Else {
                $message = ("{0}: Unexpected error getting instances. To prevent errors, {1} will exit. If present, the error detail is {2} PowerShell returned: {3}" -f `
                        [datetime]::Now, $MyInvocation.MyCommand, (($_.ErrorDetails.message | ConvertFrom-Json -ErrorAction SilentlyContinue | Select-Object -ExpandProperty errors).detail), $_.Exception.Message)
                If ($BlockLogging) { Write-Error $message } Else { Write-Error $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Error -Message $message -EventId 5417 }

                Return "Error"
            }
        }
    }
    While ($stopLoop -eq $false)

    Return $response
} #1.0.0.5
Export-ModuleMember -Alias * -Function *
