 ###### Troubleshooting things no longer needed        
# Search for the package name and get the package id
# Disabled since we have the packageID in packages.json
$packageID = ((.$StoreLibPath\StoreLib.Cli.exe search "Microsoft Photos") -split ": ")[-1]
