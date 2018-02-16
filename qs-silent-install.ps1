
$accountToAdd = "qservice"      #Windows service user to run Sense services
$serviceuserpwd = "H@veAN1ceDay" #password for local user qservice
$serviceuserpwd_enc = ConvertTo-SecureString -String $serviceuserpwd -AsPlainText -Force 
$pgadminpwd = "H@veAN1ceDay"
$license_serial = "9999000000001138" # replace with your license number
$license_control = "XXXXX" # replace with your control key
$license_name = "Your Name" 
$license_org = "Your Company"

#Get the license LEF text from http://lef1.qliktech.com/manuallef
$license_lef = "9999000000001138
Internal Qlik License 2018;;;
PRODUCTLEVEL;50;;2019-01-30
TOKENS;100;;
TIMELIMIT;;;2019-01-30
FPDH-APF5-8EDP-JBNQ-TRXX"

#Create an XML file with necessary parameters for Qlik Sense silent installer
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
$myxml | Out-File "c:\install\try.xml" -encoding utf8

