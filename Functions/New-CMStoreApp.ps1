function New-CMStoreApp {   
<#
.SYNOPSIS
    Creates a ConfigMgr application with pre-downloaded Microsoft Store applications

.DESCRIPTION
    This function creates a ConfigMgr application with pre-downloaded Microsoft Store applications.
    Used to be able to update existing Store applications on already installed clients.

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
        [string]$Owner,

        [Parameter(Mandatory=$true)]
        [string]$SupportOwner,
        
        [Parameter(Mandatory=$true)]
        [string]$AppFolder,

        [Parameter(Mandatory=$true)]
        [string]$RepoPath
    )

    Begin {
        Write-Host "CM App Creations started" -ForegroundColor DarkBlue
        if((Get-Module ConfigurationManager) -eq $null) {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" 
        }

        if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SMSProvider
        }
        Set-Location "$($SiteCode):\"

        [Int32]$TotalPackages = $packages.count
        [Int32]$count = 0

        # Get the Icon path. We split the scriptroot and get the parent (i.e. one level up from ..\Functions), then join it with the Icons folder.
        [string]$IconsPath = Join-Path (Split-Path $PSScriptRoot -Parent) -ChildPath "Icons"
    }

    Process {        
        foreach ($package in $packages) {
            $AppName = $package.Name
            $publisher = $package.Publisher
            $displayName = $package.DisplayName
            $Description = $package.description
            $Version = $package.Version
            $Icon = Join-Path $IconsPath -ChildPath "$AppName.png"
            
            $count++
            Write-Host "$count/$TotalPackages -- $DisplayName --" -ForegroundColor Green 


            # Create the application           
            $AppFullName = $displayName + " - " + $Version
            $CurrentApp = Get-CMApplication -Fast -Name $AppFullName
            if ($Version -gt $CurrentApp.SoftwareVersion) {
                Write-Host "$count/$TotalPackages - Creating CM App" -ForegroundColor cyan 
                $Parameters = @{
                    Name = $AppFullName
                    Publisher = $Publisher
                    SoftwareVersion = $Version
                    LocalizedDescription = $Description
                    AddOwner = $Owner
                    AddSupportContact = $SupportOwner
                    ReleaseDate = $(Get-Date -format yyyy-MM-dd)
                    IconLocationFile = $Icon
                    Keyword = "$AppName" 
                    AutoInstall = $true                       
                }
                $App = New-CMApplication @Parameters      
                Move-CMObject -FolderPath $AppFolder -InputObject $app
                $package | Add-Member -MemberType NoteProperty -Name 'CMApp' -Value $App -force
                
            } else {
                Write-Host "$DisplayName is already in ConfigMgr with the same or a later version - skipping" -ForegroundColor Yellow
                $package | Add-Member -MemberType NoteProperty -Name 'CMApp' -Value $CurrentApp -force
            }  
            
            $package | Add-Member -MemberType NoteProperty -Name 'Icon' -Value $Icon -force
        }
        
    }

    End {
        Write-Host "Finished with all ConfigMgr Applications" -ForegroundColor Green
        Set-Location $RepoPath
        return $packages
    }
}