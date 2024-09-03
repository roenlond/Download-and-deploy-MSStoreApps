function New-CMStoreAppDeploymentType {   
    <#
    .SYNOPSIS
        Creates a ConfigMgr app deployment type for MSStore Apps
    
    .DESCRIPTION
        This function creates a ConfigMgr application deployment type with a script installer
        The appdata is passed into it in the $packages var from when the app was created
    
    .NOTES
        Author: Patrik Ronnlund
        Date: 2024-07-22
    #>
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            [string]$SiteCode,
    
            [Parameter(Mandatory=$true)]
            [string]$SMSProvider,

            [Parameter(Mandatory=$true)]
            [object[]]$Packages,
    
            [Parameter(Mandatory=$true)]
            [string]$AppDir,

            [Parameter(Mandatory=$true)]
            [string]$InstallCommand,

            [Parameter(Mandatory=$true)]
            [string]$Comment,

            [Parameter(Mandatory=$true)]
            [string]$InstallationBehavior,

            [Parameter(Mandatory=$true)]
            [int32]$MaximumRunTime,

            [Parameter(Mandatory=$true)]
            [int32]$ExpectedRuntime
    
        )
    
        Begin {
            Write-Host "CM App DT creations started" -ForegroundColor DarkBlue
            if((Get-Module ConfigurationManager) -eq $null) {
                Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" 
            }
    
            if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
                New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SMSProvider
            }
            Set-Location "$($SiteCode):\"
    
            [Int32]$TotalPackages = $packages.count
            [Int32]$count = 0
    
        }
    
        Process {        
            foreach ($package in $packages) {                
                $count++
                
                $packageName = $package.Name
                $displayName = $package.DisplayName
                $version = $Package.Version
                $AppFullName = $Package.CMApp.LocalizedDisplayName
                Write-Host "$count/$TotalPackages -- $DisplayName --" -ForegroundColor Green
                $ContentLocation = Join-Path -Path (Join-Path -Path $AppDir -childpath $PackageName) -childPath "$Version"     
$ScriptText =  @"
`$Installed = Get-AppxProvisionedPackage -Online | where-object { $_.DisplayName -eq $PackageName -and $_.Version -eq $Version }
if ($Installed) {
    "Installed"
}
"@    
                $CurrentDT = Get-CMDeploymentType -ApplicationName $AppFullName
                if (!($CurrentDT)) {
                    Write-Host "$count/$TotalPackages - Creating CM Deployment Type" -ForegroundColor cyan 
                    $Parameters = @{
                        ApplicationName = $AppFullName
                        ContentLocation =  $ContentLocation
                        DeploymentTypeName = $AppFullName
                        InstallCommand = $InstallCommand
                        ScriptLanguage = 'Powershell'
                        ScriptText = $ScriptText
                        InstallationBehaviorType = $InstallationBehavior
                        MaximumRuntimeMins = $MaximumRunTime
                        EstimatedRuntimeMins = $ExpectedRuntime
                        Comment = $Comment
                    }
                    $DT = Add-CMScriptDeploymentType @Parameters
                    $package | Add-Member -MemberType NoteProperty -Name 'CMDT' -Value $DT -force
                } else {
                    Write-Host "$DisplayName already has a deployment type - skipping" -ForegroundColor Yellow
                    $package | Add-Member -MemberType NoteProperty -Name 'CMDT' -Value $CurrentDT -force
                }
            }            
        }
    
        End {
            Write-Host "Finished with all ConfigMgr Deployment Types" -ForegroundColor Green
            return $packages
        }
    }


