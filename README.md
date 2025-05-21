# General
Windows PowerShell module for accessing the ITGlue REST API.

This project is also published in the PowerShell Gallery at https://www.powershellgallery.com/packages/ItGlue/.

# Installation
* From PowerShell Gallery: Install-Module -Name ItGlue
* From GitHub: Save `/bin/<version>/ItGlue/<files>` to your module directory

# Behavior changes
## 1.0.0.49
- Out-PsLogging
  - Prepending [INFO], [WARNING], [ERROR], [VERBOSE] blocks before each message.
## 1.0.0.44
* Added the following commands: Get-ItGlueLocation, Get-ItGlueManufacturer, Get-ItGlueModel, Out-ItGlueAsset, and Remove-ItGlueDeviceConfig
* Updated how HTTP 429 is processed. Instead of trying indefintely, the cmdlets will exit with "Error" after 10 attempts (with one minute between each attempt). If you are being rate limited for 10 consecutive attempts, the daily limit (10k calls) has likely been reached.
## 1.0.0.32
* New behavior in logging. Instead of only logging to the Windows event log, the module now defaults to host only.
* The EventLogSource parameter is still available. If the provided source does not exist, the command will switch to host-only output.
* The new option is the LogPath parameter. Provide a path and file name (e.g. C:\Temp\log.txt) for logging. The module will attempt to create the log file, if it does not exist, and will switch to host-only output, if the file cannot be created (or the desired path is not writable).

# Breaking changes

## 2025.05.19.0
* Replaced 'IncludeUsers' from Get-ITGlueGroup with Include to Switch between the possible Includes (users, organizations, resource_type_restrictions, my_glue_account)