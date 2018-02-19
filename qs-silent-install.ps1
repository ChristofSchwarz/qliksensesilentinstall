
$serviceuser = "qservice"      #Windows service user to run Sense services
$serviceuserpwd = "H@veAN1ceDay" #password for local user qservice
#$serviceuserpwd_enc = ConvertTo-SecureString -String $serviceuserpwd -AsPlainText -Force 
$pgadminpwd = "H@veAN1ceDay"
$license_serial = "999900000000XXXX" # replace with your license number
$license_control = "XXXXX" # replace with your control key
$license_name = "Your Name" 
$license_org = "Your Company"

#Get the license LEF text from http://lef1.qliktech.com/manuallef
$license_lef = "999900000000XXXX
Internal Qlik License 2018;;;
PRODUCTLEVEL;50;;2019-01-30
TOKENS;100;;
TIMELIMIT;;;2019-01-30
FPDH-APF5-8EDP-JBNQ-TRXX"

################################################################
# Create local user and add it to the local Administrators group
################################################################
net user $serviceuser "$serviceuserpwd" /add /fullname:"Qlik Service User"
wmic useraccount WHERE "Name='$serviceuser'" set PasswordExpires=false
net localgroup "Administrators" $serviceuser /add

# Granting "Run As A Service" right to new local user
Invoke-Command -ComputerName $env:COMPUTERNAME.ToLower() -Script {
  param([string] $serviceuser)
  $tempPath = [System.IO.Path]::GetTempPath()
  $import = Join-Path -Path $tempPath -ChildPath "import.inf"
  if(Test-Path $import) { Remove-Item -Path $import -Force }
  $export = Join-Path -Path $tempPath -ChildPath "export.inf"
  if(Test-Path $export) { Remove-Item -Path $export -Force }
  $secedt = Join-Path -Path $tempPath -ChildPath "secedt.sdb"
  if(Test-Path $secedt) { Remove-Item -Path $secedt -Force }
  try {
    Write-Host ("Granting SeServiceLogonRight to user account: {0} on host: {1}." -f $serviceuser, $computerName)
    $sid = ((New-Object System.Security.Principal.NTAccount($serviceuser)).Translate([System.Security.Principal.SecurityIdentifier])).Value
    secedit /export /cfg $export
    $sids = (Select-String $export -Pattern "SeServiceLogonRight").Line
    foreach ($line in @("[Unicode]", "Unicode=yes", "[System Access]", "[Event Audit]", "[Registry Values]", "[Version]", "signature=`"`$CHICAGO$`"", "Revision=1", "[Profile Description]", "Description=GrantLogOnAsAService security template", "[Privilege Rights]", "SeServiceLogonRight = *$sids,*$sid")){
      Add-Content $import $line
    }
    secedit /import /db $secedt /cfg $import
    secedit /configure /db $secedt
    gpupdate /force
    Remove-Item -Path $import -Force
    Remove-Item -Path $export -Force
    Remove-Item -Path $secedt -Force
  } catch {
    Write-Host ("Failed to grant SeServiceLogonRight to user account: {0} on host: {1}." -f $serviceuser, $computerName)
    $error[0]
  }
} -ArgumentList $serviceuser


#########################################
# Creating QlikShare folder and share it"
#########################################
New-Item -ItemType directory -Path C:\QlikShare -ea Stop 
New-SmbShare -Name QlikShare -Path C:\QlikShare -FullAccess everyone -ea Stop

###################################
# Configuring Firewall Inbound Rule
###################################
New-NetFirewallRule -DisplayName "Qlik Sense" -Direction Inbound -LocalPort 443,4244,4242,80,4248  -Protocol TCP -Action Allow -ea Stop | Out-Null

#############################################################################
#Create an XML file with necessary parameters for Qlik Sense silent installer
#############################################################################
$tmpfilename = [System.IO.Path]::GetTempFileName() + ".xml"
$myxml = "<?xml version=`"1.0`" encoding=`"UTF-8`"?>
<SharedPersistenceConfiguration xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`">
  <DbUserName>qliksenserepository</DbUserName>
  <DbUserPassword>
  </DbUserPassword>
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

# Downloading QlikSenseSErver.exe
New-Item -ItemType directory -Path C:\install -ea Stop 
if (!(Test-Path C:\install\Qlik_Sense_setup.exe)) {   
    #Invoke-WebRequest "https://da3hntz84uekx.cloudfront.net/QlikSense/11.24/0/_MSI/Qlik_Sense_setup.exe" -OutFile "C:\install\Qlik_Sense_setup.exe"
}
Unblock-File -Path C:\install\Qlik_Sense_setup.exe

Invoke-Command -ScriptBlock {Start-Process -FilePath "c:\install\Qlik_Sense_setup.exe"  -ArgumentList "-s -log c:\install\logqlik.txt dbpassword=$pgadminpwd hostname=$($env:COMPUTERNAME) userwithdomain=$($env:computername)\$serviceuser password=$serviceuserpwd  spc=$tmpfilename" -Wait -PassThru}


