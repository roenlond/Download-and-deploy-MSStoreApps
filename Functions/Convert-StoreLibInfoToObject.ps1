function Convert-StoreLibInfoToObject {
    <#
.SYNOPSIS
    Parses a string containing application information into a PowerShell custom object.

.DESCRIPTION
    The Convert-StoreLibInfoToObject function is used to parse the results from "StoreLib query"

.PARAMETER PackageAppInfo
    The string containing the application information to be parsed. Typically fetched from .\storelib.cli.exe query <packageid>

.EXAMPLE
    $PackageInfo = .\StoreLib.Cli.exe query "$packageId"
    $ParsedPackageInfo = Convert-StoreLibInfoToObject -PackageAppInfo $PackageInfo

.NOTES
    Author: Patrik Ronnlund
    Date: 2024-07-22
#>
    param (
        [string]$PackageAppInfo
    )

    # Initialize an empty hashtable to store the parsed data
    $appInfo = @{}

    # Parse each line and add to the hashtable
    foreach ($line in $packageinfo) {
        if ($line -match "^(.*?):\s*(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $appInfo[$key] = $value
        }
    }

    # Convert the hashtable to a custom object
    $appObject = [PSCustomObject]$appInfo 

    # Output the custom object
    return $appObject
}
