<#
.SYNOPSIS
    Creates a "phased" deployment for a given application.

.DESCRIPTION
    This function creates phased deployments for a specified application, sends an email summary of the deployments, and returns the updated packages array back to the StoreApps-mgmt script.

.PARAMETER deploymentName
    The name of the deployment.

.PARAMETER collections
    An array of collection IDs for the phased deployments.

.PARAMETER emailTo
    The recipient email address for the deployment summary.

.PARAMETER emailFrom
    The sender email address for the deployment summary.

.PARAMETER smtpServer
    The SMTP server used to send the email.

.PARAMETER packages
    An array of package objects containing the application details.

.EXAMPLE
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

.NOTES
    Author: Patrik Ronnlund
    Date: 2024-07-23
#>
function New-CMStoreAppPhasedDeployment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$collections,

        [Parameter(Mandatory=$true)]
        [string]$emailTo,

        [Parameter(Mandatory=$true)]
        [string]$emailFrom,

        [Parameter(Mandatory=$true)]
        [string]$smtpServer,

        
        [Parameter(Mandatory=$true)]
        [string]$Subject,

        [Parameter(Mandatory=$true)]
        [object[]]$packages,

        [Parameter(Mandatory=$true)]
        [string]$TimeForDeployment
    )

    begin {
        # Function to calculate available times for deployments
        function Get-WeekdayDates {
            param (
                [int]$AmountOfDays,
                [string]$Time
            )
        
            $dates = @()
            $currentDate = Get-Date
            $daysAdded = 0
        
            while ($dates.Count -lt $AmountOfDays) {
                if ($currentDate.DayOfWeek -ne 'Friday' -and $currentDate.DayOfWeek -ne 'Saturday' -and $currentDate.DayOfWeek -ne 'Sunday') {
                    $dates += [datetime]::ParseExact("$($currentDate.ToString('yyyy-MM-dd')) $Time", 'yyyy-MM-dd hh:mmtt', $null)
                    $daysAdded++
                }
        
                if ($daysAdded -eq 1) {
                    $currentDate = $currentDate.AddDays(1)
                } elseif ($daysAdded -eq 2) {
                    $currentDate = $currentDate.AddDays(6)
                } else {
                    $currentDate = $currentDate.AddDays(1)
                }
            }
        
            return $dates
        }     

        # Function to create deployments
        function Create-Deployments {
            param (
                [string]$deploymentName,
                [string[]]$collections,
                [datetime[]]$availableTimes,
                [object[]]$packages
            )
        
            $deployments = @()
            for ($i = 0; $i -lt $packages.Length; $i++) {
                $DisplayName = $($packages[$i].cmapp.localizeddisplayname)
                for ($j = 0; $j -lt $availableTimes.Length; $j++) {
                    Write-Host "Creating deployment for app $DisplayName to collection $($collections[$j]) at $($availableTimes[$j])"
                    $CurrentDeployment = Get-CMApplicationDeployment -Name $DisplayName -CollectionId $($collections[$j])
                    if (!($CurrentDeployment)) {
                        $deployment = New-CMApplicationDeployment -ApplicationName $DisplayName -CollectionId $collections[$j] -DeployPurpose Available -AvailableDateTime $availableTimes[$j] -TimeBaseOn LocalTime -UserNotification DisplaySoftwareCenterOnly
                        $deployments += $deployment
                        $packages[$i] | Add-Member -MemberType NoteProperty -Name "DeploymentInfo" -Value $deployment -force
                    } else {
                        Write-Host "$DisplayName is already deployed to $($collections[$j]) - skipping" -ForegroundColor Yellow
                        $packages[$i] | Add-Member -MemberType NoteProperty -Name "DeploymentInfo" -Value $CurrentDeployment -force
                    }
                }
            }
            return $deployments
        }        

        # Function to prepare email body
        function New-EmailBody {
            param (
                [object[]]$Deployments,
                [object[]]$Packages
            )
        
            # Create a dictionary to map application names to icon paths
            $AppIcons = @{}
            foreach ($package in $Packages) {
                $AppIcons[$package.CMApp.LocalizedDisplayName] = $package.Icon
            }
        
            $GroupedDeployments = $Deployments | Group-Object -Property ApplicationName
        
            $emailBody = "<html><body><h2>New Microsoft Store App Deployments</h2>"
            $emailBody += foreach ($AppGroup in $GroupedDeployments) {
                $AppName = $AppGroup.Name
                $IconUrl = $AppIcons[$AppName]
                $Time = (($($appgroup.Group.Starttime)).ToUniversalTime()).tostring()
                "<h3><img src='$IconUrl' alt='$AppName' width='30' height='30' />‎ $AppName</h3>" 
                foreach ($Deployment in $AppGroup.Group) {
                    Write-Output "Deployed to <strong>$($Deployment.CollectionName)</strong> <em>($($Deployment.TargetCollectionID))</em>
                    </br>
                    <blockquote> Available at: <u>$Time</u></blockquote>
                    </br>"
                }    
            }
            $emailBody += "</body></html>"
            return $emailBody
        }             

        # Function to send email
        function Send-DeploymentEmail {
            param (
                [string]$subject,
                [string]$body,
                [string]$to,
                [string]$from,
                [string]$smtp
            )
        
            Write-Host "Sending email to $to"
            $message = New-Object system.net.mail.mailmessage
            $message.subject = $subject
            $message.body = $body
            $message.IsBodyHtml = $true
            $message.to.add($to)
            $message.from = $from
        
            $smtpClient = New-Object Net.Mail.SmtpClient($smtp)
            try {
                $smtpClient.Send($message)
                Write-Host "Email sent successfully"
            } catch {
                Write-Host "Email failed to send"
            }
            
        }
        

        Write-Host "CM App Deployments started" -ForegroundColor DarkBlue
        if((Get-Module ConfigurationManager) -eq $null) {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" 
        }

        if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $SMSProvider
        }
        Set-Location "$($SiteCode):\"
    }

    process {
        $availableTimes = Get-WeekdayDates -AmountOfDays $collections.length -Time $TimeForDeployment
        $deployments = Create-Deployments -collections $collections -availableTimes $availableTimes -packages $packages
        $emailbody = New-EmailBody -Deployments $Deployments -Packages $packages
        Send-DeploymentEmail -subject $Subject -body $emailBody -to $emailTo -from $emailFrom -smtp $smtpServer
    }

    end {
        # Return the updated packages array
        return $packages
    }
}
