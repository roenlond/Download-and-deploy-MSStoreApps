function Start-CMStoreAppContentDistribution {   
    <#
    .SYNOPSIS
        Distributes content for a CM MS Store application
    
    .DESCRIPTION
        Distributes content for a CM MS Store application to input DP Groups
    
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
            [string]$DeploymentCollectionID
        )
    
        Begin {
            Write-Host "CM App content distribution started" -ForegroundColor DarkBlue
            if((Get-Module ConfigurationManager) -eq $null) {
                Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" 
            }
    
            if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
                New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SMSProvider
            }
            Set-Location "$($SiteCode):\"   
            [Int32]$TotalPackages = $packages.count
            [Int32]$count = 0

            # Get the deployment collection name from ID
            $DeploymentCollectionName = (Get-CMCollection -Id $DeploymentCollectionID).Name
        }
    
        Process {        
            foreach ($package in $packages) {
                $AppName = $package.CMApp.LocalizedDisplayName  
                $displayName = $package.DisplayName             
                $count++
                Write-Host "$count/$TotalPackages -- $DisplayName --" -ForegroundColor Green          
                Write-Host "$count/$TotalPackages - Distributing content..." -ForegroundColor cyan 
                Start-CMContentDistribution -ApplicationName $AppName -CollectionName $DeploymentCollectionName       
            }            
        }
    
        End {
            Write-Host "Finished with all ConfigMgr content distribution" -ForegroundColor Green
        }
    }