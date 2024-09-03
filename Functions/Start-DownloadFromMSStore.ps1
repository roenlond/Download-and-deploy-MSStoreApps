function Start-DownloadFromMSStore {
    param (
        [string]$StoreLibPath,
        [string]$proxy,
        [object[]]$packages,
        [string]$AppDir
    )
    <#
        .SYNOPSIS
        This script uses a custom StoreLib (added proxy support) to download the latest version of any Microsoft Store app and creates the source content
    
        .DESCRIPTION            
        It only downloads the latest version online if the local version is older or missing
        It also fetches som metadata and appends the packages array with them, then returns them for use outside this script. 
        MOLD is then used to create the source content (the deploy-application.ps1 script) with customized properties based on the template and answer file.
    
        .LINK
        Mold documentation: https://blog.belibug.com/post/ps-mold/
        Mold Github: https://github.com/belibug/Mold
    
        .LINK
        StoreLib Upstream Github: https://github.com/StoreDev/StoreLib
            Proxy support added by Patrik Ronnlund so it's not in the upstream github.
            StoreLib source code with added proxy support is in the local .\StoreLib_src folder.
            
            
        .AUTHOR
        Patrik Ronnlund
        Date: 2024-07-19    
    #>
    

    Begin {
        Write-Host "Store Download started" -ForegroundColor DarkBlue
        [Int32]$TotalPackages = $packages.count
        [Int32]$count = 0
    }    
    
    Process {
        foreach ($package in $packages) {
            # Get the package name and properties
            $packageName = $package.Name
            $installTitle = $package.InstallTitle
            $publisher = $package.Publisher
            $minimumVersion = $package.MinimumVersion
            $displayName = $package.DisplayName
            $PackageID = $package.PackageID
            $ProcessName = $package.ProcessName
            
            $count++
            Write-Host "$count/$TotalPackages -- $DisplayName --" -ForegroundColor Green
        
            # Get all packages associated with the app
            Write-Host "$count/$TotalPackages - Getting packages..." -ForegroundColor cyan
            $PackageResult = .$StoreLibPath\StoreLib.Cli.exe packages "$packageId"

            # Get the app info associated with the app
            Write-Host "$count/$TotalPackages - Getting app info..." -ForegroundColor cyan
            $PackageInfo = .$StoreLibPath\StoreLib.Cli.exe query "$packageId" -l SV            
        
            # Parse and sort
            Write-Host "$count/$TotalPackages - Parsing and sorting..." -ForegroundColor cyan
            $PackageAppInfoParsed = Convert-StoreLibInfoToObject -PackageAppInfo $PackageInfo    
            $PackageResultParsed = Convert-StoreLibToObject $packageResult # PackageResult returns an array of objects in a raw format, so we need to parse it into usable objects
            $LatestPackage = $PackageResultParsed | Sort-Object -Property name,version -Descending | Where-Object -Property name -eq $packageName | Select-Object -First 1
        
            # Get the properties
            $name = $LatestPackage.Name
            $url = $LatestPackage.Url
            $fileType = $LatestPackage.FileType
            $FileSize = $LatestPackage.Size
            $version = $LatestPackage.Version

            $Description = $PackageAppInfoParsed.Description
            $IsMicrosoftPublished = $PackageAppInfoParsed.'Is a Microsoft Listing'
        
            # Setup the Application's Path and create the Files Dir if it doesn't already exist
            $AppPath = Join-Path -Path (Join-Path -Path $AppDir -childpath $PackageName) -childPath "$Version"
            $AppPathFiles = Join-Path -Path $AppPath -ChildPath "Files"
            if (!(Test-Path $AppPathFiles))  {            
                New-Item -Path "$AppPathFiles" -ItemType Directory -force | out-null
            }
        
            # We get the latest local version so we can skip the download if latest version already exists
            $LatestVersionPath = Join-path $AppPath -ChildPath "LatestVersion.txt"
            try {
                $LatestLocalVersion =  Get-content -Path $LatestVersionPath -ErrorAction Stop
            } catch {
                # If the file doesn't exist, we catch it 
                $LatestLocalVersion = $false
            }

            # Add the app version found so we can return it back
            $package | Add-Member -MemberType NoteProperty -Name 'Version' -Value $version -force
            $package | Add-Member -MemberType NoteProperty -Name 'Description' -Value $Description -force
            $package | Add-Member -MemberType NoteProperty -Name 'IsMicrosoftPublished' -Value $IsMicrosoftPublished -force
            $package | Add-Member -MemberType NoteProperty -Name 'FileSize' -Value $FileSize -force
            $package | Add-Member -MemberType NoteProperty -Name 'FileType' -Value $FileType -force

            # Exit if the version is below the minimum version or we already have a local version of the same or later version
            if (($version -ge $minimumVersion) -and ($LatestLocalVersion -lt $Version)) {   
                ##### Download section
                #----------------------------------#
                Write-Host "$count/$TotalPackages - Starting BITS transfer..." -ForegroundColor cyan
                $destination = Join-Path $AppPathFiles -ChildPath "$packageName.$fileType"        
                Start-BitsTransfer -Source $url -Destination $destination -ProxyUsage Override -ProxyList $proxy
        
                # Write the latest file to text
                Set-content -Path $LatestVersionPath  -Value $Version

                # Set NewApp to True so we can process it further after the download
                $package | Add-Member -MemberType NoteProperty -Name 'NewApp' -Value $true -force
        
                ##### Mold section 
                #----------------------------------#
                Write-Host "$count/$TotalPackages - Invoking Mold Template..." -ForegroundColor cyan
        
                # Create the Mold answer file
                $MoldAnswerFileObject = get-Content .\Mold_Answer_File.json | ConvertFrom-Json
        
                # Update the "Answer" field with the corresponding variables
                foreach ($item in $MoldAnswerFileObject) {
                    switch ($item.Key) {
                        "Vendor" { $item.Answer = $publisher }
                        "AppName" { $item.Answer = $installTitle }
                        "Version" { $item.Answer = $Version }
                        "Date" { $item.Answer = $(Get-Date -format yyyy-MM-dd) }
                        "AppProcessName" { $item.Answer = $ProcessName }
                        "InstallTitle" { $item.Answer = $installTitle  }
                    }
                }
        
                # Convert back to Json and output the answerfile
                $updatedJson = $MoldAnswerFileObject | ConvertTo-Json
                $MoldAnswerFile = ".\AnswerFiles\$Name.json"
                $updatedJson | Set-content -Path $MoldAnswerFile
        
                # Create the Deploy-Application script from the template with the answer file. 
                # This also copies the other files from the Template folder (i.e. the rest of PSADT)
                Invoke-Mold -TemplatePath .\Templates -DestinationPath $AppPath -AnswerFile $MoldAnswerFile    
        
            } else {
                if  (!($version -ge $minimumVersion)) {
                    Write-Host "$displayName of of version $Version is below the minimum version ($minimumVersion)" -ForegroundColor Red
                } elseif (!($LatestLocalVersion -lt $Version)) {
                    Write-Host "$displayName of version $Version has a later or equal local version: ($LatestLocalVersion) - skipping download" -ForegroundColor Yellow
                }   
                
                $package | Add-Member -MemberType NoteProperty -Name 'NewApp' -Value $false -force

            }
        }
    }    

    End {
        Write-Host "Finished with all packages" -ForegroundColor Green
        return $packages
    }
}