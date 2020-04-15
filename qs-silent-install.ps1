$execpolicy_before = Get-ExecutionPolicy
Set-ExecutionPolicy Unrestricted

#Localization: English Windows
$localadmingroupname = "Administrators"
$shareaccessto = "everyone"

#Localization: German Windows
# $localadmingroupname = "Administratoren" 
# $shareaccessto = "Jeder"

$serviceuser = "qservice"      #Windows service user to run Sense services
$serviceuserpwd = "!1qayXSW23edc!" #password for local user qservice
#$serviceuserpwd_enc = ConvertTo-SecureString -String $serviceuserpwd -AsPlainText -Force 
$pgadminpwd = "!1qayXSW23edc!"
$license_serial = "1234567890121142" # replace with your license number
$license_control = "12345" # replace with your control key
$license_name = "Your Name" 
$license_org = "Your Company"
$localdatapath = "C:\QlikData"
$dirofinstaller = $PSScriptRoot  # Qlik_Sense_setup.exe is expected in the same folder as this .ps1 file
$tmppath = Split-Path -parent ([System.IO.Path]::GetTempFileName()) 

#Get the license LEF text from http://lef1.qliktech.com/manuallef
$license_lef = "1234567890121142
Qlik Sense Enterprise;;;
Possible to use for external;Beta for Analyst evaluation;;
PRODUCTLEVEL;XX;;####-##-##
TOKENS;XX;;
TIMELIMIT;;;####-##-##
OVERAGE;NO;;
XXXX-XXXX-XXXX-XXXX-XXXX"

################################################################
# Finding or downloading Qlik_Sense_server.exe (installer)
################################################################
If (!(Test-Path "$dirofinstaller\Qlik_Sense_setup.exe")) {
    echo "Qlik_Sense_setup.exe not found in $dirofinstaller; trying to download ..."
    
    if (!(Test-Path "$tmppath\Qlik_Sense_setup.exe")) {   
    	# Downloading QlikSenseServer.exe April 2018 release
        Invoke-WebRequest "https://da3hntz84uekx.cloudfront.net/QlikSense/12.16/0/_MSI/Qlik_Sense_setup.exe" -OutFile "$tmppath\Qlik_Sense_setup.exe"
    }
    Unblock-File -Path "$tmppath\Qlik_Sense_setup.exe"
    $dirofinstaller = $tmppath
}


###########################################################################
Write-Host "Create local user and add it to the local Administrators group"
###########################################################################
net user $serviceuser "$serviceuserpwd" /add /fullname:"Qlik Service User"
wmic useraccount WHERE "Name='$serviceuser'" set PasswordExpires=false
net localgroup $localadmingroupname $serviceuser /add
# Granting "Run As A Service" right to new local user

$sidstr = $null
try {
	$ntprincipal = new-object System.Security.Principal.NTAccount "$serviceuser"
	$sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	$sidstr = $sid.Value.ToString()
} catch {
	$sidstr = $null
}
Write-Host "Account: $($serviceuser)" -ForegroundColor DarkCyan
if( [string]::IsNullOrEmpty($sidstr) ) {
	Write-Host "Account not found!" -ForegroundColor Red
	exit -1
}
Write-Host "Account SID: $($sidstr)" -ForegroundColor DarkCyan
$tmp = [System.IO.Path]::GetTempFileName()
Write-Host "Export current Local Security Policy" -ForegroundColor DarkCyan
secedit.exe /export /cfg "$($tmp)" 

$c = Get-Content -Path $tmp 
$currentSetting = ""
foreach($s in $c) {
	if( $s -like "SeServiceLogonRight*") {
		$x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		$currentSetting = $x[1].Trim()
	}
}

if( $currentSetting -notlike "*$($sidstr)*" ) {
	Write-Host "Modify Setting ""Logon as a Service""" -ForegroundColor DarkCyan
	if( [string]::IsNullOrEmpty($currentSetting) ) {
		$currentSetting = "*$($sidstr)"
	} else {
		$currentSetting = "*$($sidstr),$($currentSetting)"
	}
	Write-Host "$currentSetting"
	$outfile = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeServiceLogonRight = $($currentSetting)
"@

	$tmp2 = [System.IO.Path]::GetTempFileName()	
	Write-Host "Import new settings to Local Security Policy" -ForegroundColor DarkCyan
	$outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force
	#notepad.exe $tmp2
	Push-Location (Split-Path $tmp2)
	
	try {
		secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS 
		#write-host "secedit.exe /configure /db ""secedit.sdb"" /cfg ""$($tmp2)"" /areas USER_RIGHTS "
	} finally {	
		Pop-Location
	}
} else {
	Write-Host "NO ACTIONS REQUIRED! Account already in ""Logon as a Service""" -ForegroundColor DarkCyan
}
Write-Host "Done." -ForegroundColor DarkCyan



#########################################
Write-Host "Creating QlikShare folder and share it"
#########################################
New-Item -ItemType directory -Path $localdatapath 
New-SmbShare -Name QlikShare -Path $localdatapath -FullAccess $shareaccessto

##############################################
Write-Host "Configuring Firewall Inbound Rule"
##############################################
New-NetFirewallRule -DisplayName "Qlik Sense" -Direction Inbound -LocalPort 443,4244,4242,80,4248  -Protocol TCP -Action Allow -ea Stop | Out-Null

#############################################################################
#Create an XML file with necessary parameters for Qlik Sense silent installer
#############################################################################
$tmpfilename = $dirofinstaller + "\qsense_install_settings.xml"
$myxml = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>
<SharedPersistenceConfiguration xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`">
  <DbUserName>qliksenserepository</DbUserName>
  <DbUserPassword>$pgadminpwd</DbUserPassword>
  <DbHost>$($env:COMPUTERNAME)</DbHost>
  <DbPort>4432</DbPort>
  <RootDir>\\$($env:COMPUTERNAME)\QlikShare</RootDir>
  <StaticContentRootDir>\\$($env:COMPUTERNAME)\QlikShare\StaticContent</StaticContentRootDir>
  <CustomDataRootDir>\\$($env:COMPUTERNAME)\QlikShare\CustomData</CustomDataRootDir>
  <ArchivedLogsDir>\\$($env:COMPUTERNAME)\QlikShare\ArchivedLogs</ArchivedLogsDir>
  <AppsDir>\\$($env:COMPUTERNAME)\QlikShare\Apps</AppsDir>
  <CreateCluster>true</CreateCluster>
  <InstallLocalDb>true</InstallLocalDb>
  <ConfigureDbListener>true</ConfigureDbListener>
  <ListenAddresses>*</ListenAddresses>
  <IpRange>0.0.0.0/0</IpRange>
</SharedPersistenceConfiguration>";
$myxml | Out-File "$tmpfilename" -encoding utf8


Start-Process -FilePath "$dirofinstaller\Qlik_Sense_setup.exe" -ArgumentList "-s -log $dirofinstaller\logqlik.txt dbpassword=$pgadminpwd hostname=$($env:COMPUTERNAME) userwithdomain=$($env:computername)\$serviceuser password=$serviceuserpwd spc=""$tmpfilename""" -Wait -PassThru

# Wait for Qlik Services to come up.
Write-Host "Connecting to the Qlik Sense Repository Service"
$svc = Get-Service -Name QlikSenseRepositoryService
while ($svc.Status -ne "Running")
{
	Start-Sleep -seconds 10
	$svc = Get-Service -Name QlikSenseRepositoryService
}
Write-Host "Waiting 90 seconds before attempting to connect to Central Node"
Start-Sleep 90

# Next: Install and user Qlik-CLI from Open Source https://github.com/ahaydon/Qlik-Cli 
Get-PackageProvider -Name NuGet -ForceBootstrap
Install-Module Qlik-Cli
Import-Module Qlik-Cli
Connect-Qlik $env:COMPUTERNAME -UseDefaultCredentials
# Apply license
Set-QlikLicense -serial $license_serial -control $license_control -name "$license_name" -organization "$license_org" -lef "$license_lef"

#Create RootAdmin (e.g. for service user "qservice")
#Set Auto-assign-token
#Create database connector for Tosca
#Import Apps(s)
#Import Extension(s)


#Write-Host ":-) Creating new Qlik Sense data connection 'energydata'"
#$qsconn = new-qlikdataconnection -name "energydata" -connectionstring 'CUSTOM CONNECT TO "provider=QvOdbcConnectorPackage.exe;driver=postgres;host=localhost;port=4432;db=postgres;FetchTSWTZasTimestamp=1;MaxVarcharSize=262144;"' -type "QvOdbcConnectorPackage.exe" -username "qliksenserepository" -password "Qlik1234"
#Write-Host ":-) created new Qlik Sense data connection $($qsconn.id)"
#$qsrule = New-QlikRule -category Security -name "Access to lib connection energydata" -rule '((user.userId like "*"))' -action 2 -ruleContext both -resourceFilter "DataConnection_$($qsconn.id)"
#Write-Host ":-) created new Security Role for above connection $($qsrule.id)"


#Write-Host ":-) Exporting client certificate to the node app's folder"
#Export-QlikCertificates qmi-qs-sessapp2
#copy "C:\ProgramData\Qlik\Sense\Repository\Exported Certificates\qmi-qs-sessapp2\client.*" "c:\sessionapps-master"


#Write-Host ":-) Updating Central Virtual Proxy settings"
#$vproxy = get-QlikVirtualProxy | where {$_.description -like "Central*" }
#Update-QlikVirtualProxy -id $vproxy.id -additionalResponseHeaders "Access-Control-Allow-Origin: http://qmi-qs-sessapp2:4000`nAccess-Control-Allow-Credentials: true" -websocketCrossOriginWhiteList {qmi-qs-sessapp2} 


#Write-Host ":-) Publishing and reloading EnergyData app"
#$streamid = (get-QlikStream | where {$_.name -eq "Everyone" }).id
#$qapp = get-QlikApp | where {$_.name -like "EnergyData*" }
#publish-qlikapp -id $qapp.id -stream $streamid
#$qtask = New-QlikTask -appId $qapp.id -name "Reload of $($qapp.name)"
#Start-QlikTask -id $qtask.id

Write-Host "Done." -ForegroundColor DarkCyan

