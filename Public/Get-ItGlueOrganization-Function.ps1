Function Get-ItGlueOrganization {
    <#
        .DESCRIPTION
            Connects to the ITGlue API and returns one or organizations.
        .NOTES
            V1.0.0.0 date: 5 April 2019
                - Initial release.
        .PARAMETER CustomerName
            Enter the name of the desired customer, or "All" to retrieve all organizations.
        .PARAMETER CustomerId
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
                If ($loopCount -ge 5) {
                    $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                    If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
                If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty message) -eq "Endpoint request timed out") {
                    $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
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
                    If ($loopCount -ge 5) {
                        $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty message) -eq "Endpoint request timed out") {
                        $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
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
                If ($loopCount -ge 5) {
                    $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                    If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
                If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty message) -eq "Endpoint request timed out") {
                    $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
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
                    If ($loopCount -ge 5) {
                        $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                        If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                        Return "Error"
                    }
                    If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty message) -eq "Endpoint request timed out") {
                        $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
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

        $organizations = $organizations | Where-Object {$_.attributes.name -eq $CustomerName}

        Return $organizations
    }
    ElseIf ($CustomerId) {
        $message = ("Getting organization with ID." -f $CustomerId)
        If (($BlockLogging) -AND ($PSBoundParameters['Verbose'])) { Write-Verbose $message } ElseIf ($PSBoundParameters['Verbose']) { Write-Verbose $message; Write-EventLog -LogName Application -Source $EventLogSource -EntryType Information -Message $message -EventId 5417 }

        $loopCount = 0
        Do {
            Try {
                $loopCount++

                ($organizations = Invoke-RestMethod -Method GET -Headers $header -Uri "$ItGlueUriBase/organizations/$CustomerId" -ErrorAction Stop).data

                $stopLoop = $True
            }
            Catch {
                If ($loopCount -ge 5) {
                    $message = ("{0}: Loop-count limit reached, {1} will exit." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
                    If ($BlockLogging) { Write-Host $message -ForegroundColor Red } Else { Write-Host $message -ForegroundColor Red; Write-EventLog -LogName Application -Source $eventLogSource -EntryType Error -Message $message -EventId 5417 }

                    Return "Error"
                }
                If (($_.ErrorDetails.message | ConvertFrom-Json | Select-Object -ExpandProperty message) -eq "Endpoint request timed out") {
                    $message = ("{0}: Rate limit exceeded, retrying in 60 seconds." -f (Get-Date -Format s), $MyInvocation.MyCommand, $_.Exception.Message)
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
} #1.0.0.0