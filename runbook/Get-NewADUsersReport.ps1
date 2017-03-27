<#
.NOTES      
    File Name		: Get-NewADUsersReport.ps1
    Version     	: 1.0
    Date		: 1/5/2017   
    Author		: Bryce Harding
    Email		: BryceH@AcceleraSolutions.com
    Updates		: Added Prompts for User Input
    To Do		: Clean up user interface
    
.SYNOPSIS
    Script created to generate reports of recently created AD User Objects.

.DESCRIPTION
    This function "Get-NewADUserReport" will generate a report of new Active Directory user accounts created in number of days (X value) 
    and email the report from admin@accelera.onmicrosoft.com and to the recipient specified when prompted. 
    Script could be helpful for user migrations, AD cleanup, security and naming convention quality assurance.

.LINK
	http://www.accelerasolutions.com/

.INPUTS
    Number of Days:
    Report MailTo:

.OUTPUTS
    Information emailed to recipient(s)

.EXAMPLE (Run Script)
	.\Get-NewADUserReport.ps1
		
.EXAMPLE (Note: Function or Cmdlet "Get-NewADUserReport" will be available until PowerShell session ends.
	Get-NewADUserReport 
	
.PARAMETER
    None
#>

# Start of Script 

Function Get-NewUserReport{
#Parameter prompt for Input "Number of Days"

Param (
    [int]$Age = (Read-Host -Prompt "Number of Days"),
	[string]$To = (Read-Host -Prompt "Report MailTo"),
    #[int]$Age = 18,
	#[string]$To = "sigaralerts@accelerasolutions.com",
	[string]$From = "admin@accelera.onmicrosoft.com",
	[string]$SMTPServer = "smtp.accelera.com",
    [int]$Port = 25
)

# Create ParentOU Attribute
$dn -split '(?<![\\]),'

function Get-ParentOU ([string] $dn) {
     $parts = $dn -split '(?<![\\]),'
     $parts[1..$($parts.Count-1)] -join ','
}

$ParentOU = @{Name='ParentOU'; Expression={ Get-ParentOU $_ } }
$ParentOU = @{Name='ParentOU'; Expression={ Get-ParentOU $_.DistinguishedName } }


#Find users that have been created in the past day
$Then = (Get-Date).AddDays(-$Age).Date

#Filter only enabled user created whencreated ($Age = X)
$Users = Get-ADUser -Server Accelera-DC01.accelera.com -Filter {(Enabled -eq "True") -and (whenCreated -ge $Then)} -Properties whenCreated, DisplayName, proxyaddresses 

# Create HTML Message

$SMTPProperties = @{
	From = $From
	To = $To
	Subject = "Accelera New Users Created Since $Then"
	SMTPServer = $SMTPServer
    UseSSL = $UseSSL
    Port = $Port
}

$Header = @"
<style>
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #6495ED;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
</style>
"@

#Create the email body with user key attributes
If ($Users)
{	$Pre = "<p><h3>There were $($Users.Count) user objects created since $Then</h3></p><br>"
	$Body = $Users | Select whenCreated,displayName,SAMAccountName,userPrincipalName,@{L='ProxyAddress'; E={$_.proxyaddresses -join"; "}},$ParentOU | Sort whenCreated | ConvertTo-HTML -PreContent $Pre -Head $Header | Out-String
}

Else
{	$Body = "<br>No users created since $Then."
}

Try {
    Send-MailMessage @SMTPProperties -Body $Body -BodyAsHtml -ErrorAction Stop
}
Catch {
    $Users | Select SamAccountName,Name,whenCreated,DistinguishedName | Format-Table -AutoSize
    Write-Host "Unable to send email because: $($Error[0])" -ForegroundColor Red
}

}
# End of Script

Get-NewADUserReport
