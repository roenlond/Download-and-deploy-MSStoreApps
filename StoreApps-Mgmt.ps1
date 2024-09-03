
<#
.SYNOPSIS
    Downloads selected Microsoft Store Applications via Proxy, creates the application in ConfigMgr, distributes the content and deploys the applications in phases.


.LINK 
	https://github.com/roenlond
	https://roenlond.github.io/

.NOTES
    Author: Patrik Ronnlund
    Date: 2024-07-23

	WORK IN PROGRESS
#>

Set-ExecutionPolicy -ExecutionPolicy Bypass # While testing only

##### Variables
#----------------------------------#

# Paths
[string]$RepoPath = "FileSystem::\\UNCPath" # Where the repository is saved
[string]$AppDir = "\\UNCPATH\Applications\MicrosoftStore" # Where the actual apps will be stored (your content for CM)
[string]$StoreLibPath = Join-Path $RepoPath -childpath "StoreLib"
[string]$PackagesPath = Join-Path $RepoPath -childpath "packages.json"
[string]$FunctionsPath = Join-Path $RepoPath -childpath "Functions"
[string]$MoldModulePath = Join-Path $RepoPath -ChildPath "Modules\Mold\Mold.psm1"

# This variable is only used for the BITS-transfer. StoreLib uses the proxy in .\StoreLib\appsettings.json
[string]$proxy = "http://proxy.contoso.com:8080"

# Packages are initialized from the JSON but will be appended as we go
[object[]]$packages = Get-Content $PackagesPath -raw | ConvertFrom-Json

# ConfigMgr Variables
[string]$SiteCode = "ABC"
[string]$SMSProvider = "smsprovider.contoso.com"

# Load custom functions and the mold templating engine
Get-ChildItem -Path $FunctionsPath -Filter *.ps1 | ForEach-Object { . $_.FullName }
Import-Module $MoldModulePath


##### Main script
#----------------------------------#

# Download and create source content
Set-Location $RepoPath
$Parameters = @{
	StoreLibPath = $StoreLibPath
	proxy = $proxy
	packages = $packages
	AppDir = $AppDir
}
$Packages = Start-DownloadFromMSStore @Parameters

Write-Host "Store Download completed" -ForegroundColor DarkBlue 
Write-Host "------------------------" -ForegroundColor DarkBlue

# Filter out packages that are old so that we only handle new versions/packages from now on
$packages = $packages | Where-Object { $_.NewApp -ne $false }

# Create the ConfigMgr Applications
$CMAppParam = @{
	SiteCode = $SiteCode
	SMSProvider = $SMSProvider
	Packages = $Packages
	Owner = "UserName"
	SupportOwner = "SupportUserName"
	AppFolder = "ABC:\Application\Client\Microsoft\MicrosoftStore" # Where the file will be placed in ConfigMgr console
	RepoPath = $RepoPath
}
$Packages = New-CMStoreApp @CMAppParam

Write-Host "CM App Creations completed" -ForegroundColor DarkBlue 
Write-Host "------------------------" -ForegroundColor DarkBlue 

# Create the ConfigMgr Application Deployment Types
$CMAppDTParam = @{
	SiteCode = $SiteCode
	SMSProvider = $SMSProvider
	Packages = $Packages
	AppDir = $AppDir
	InstallCommand = "Deploy-Application.exe Install"
	Comment = ""
	InstallationBehavior = 'InstallForSystem'
	MaximumRunTime = 15
	ExpectedRuntime = 5
}

$Packages = New-CMStoreAppDeploymentType @CMAppDTParam

Write-Host "CM App DT Creations completed" -ForegroundColor DarkBlue 
Write-Host "------------------------" -ForegroundColor DarkBlue 

# Distribute the content
$CMAppDistParam = @{
	SiteCode = $SiteCode
	SMSProvider = $SMSProvider
	Packages = $Packages
	DeploymentCollectionID = "ABC000123" # Collection ID of a collection that you have set Distribution Point Groups to (this is where the content will be distributed to)
}
Start-CMStoreAppContentDistribution @CMAppDistParam

Write-Host "CM App Content Distribution completed" -ForegroundColor DarkBlue 
Write-Host "------------------------" -ForegroundColor DarkBlue 


# Create the ConfigMgr Deployments and email admins
$CMAppDeployParam = @{
	collections    = @(
		"ABC000123", 
		"ABC000124", 
		"ABC000125"
		) # Phase 1, 2, 3, collections for deployment. Add more as needed.
	emailTo        = "admin@contoso.com"
	emailFrom      = "automations@contoso.com"
	smtpServer     = "smtp.contoso.com"
	Subject        = "Microsoft Store Apps - New Deployments"
	packages = $Packages
	TimeForDeployment = "12:00" # client local time
}
$Packages = New-CMStoreAppPhasedDeployment @CMAppDeployParam

Write-Host "CM App Deployments completed" -ForegroundColor DarkBlue 
Write-Host "------------------------" -ForegroundColor DarkBlue 



<# 

TO DO

# Superseed old versions of the app (When a new app is created, we want to check for any old CM apps and superseed those.)
$CMAppSuperseedParam = @{
	packages = $packages
}
$Packages = Invoke-CMStoreAppSuperseedence @CMAppSuperseedParam

Write-Host "CM App Superseedence completed" -ForegroundColor DarkBlue 
Write-Host "------------------------" -ForegroundColor DarkBlue 


# Finally we want to delete old versions that are superseeded fully, i.e. all phases of the new app are completed
$CMAppRemovalParam = @{
	packages = $packages
}
$Packages = Remove-SuperseededCMStoreApps @CMAppRemovalParam

Write-Host "CM App removal completed" -ForegroundColor DarkBlue 
Write-Host "------------------------" -ForegroundColor DarkBlue 

#>