# Simple way to directly call the QRS API from Powershell of the Server console

## Ignore warning of self-signed certificate
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
## 

$headers = @{}
$headers.Add("X-Qlik-Xrfkey", "1234567890123456")
$headers.Add("X-Qlik-User", "UserDirectory=INTERNAL;UserId=sa_api")
$cert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where {$_.Subject -like '*QlikClient*'}
$url = 'https://localhost:4242/qrs/about?xrfkey=1234567890123456'
Invoke-RestMethod $url -Method 'GET' -Headers $headers -Certificate $cert
