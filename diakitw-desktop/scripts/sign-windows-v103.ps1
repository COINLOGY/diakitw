# Run on a trusted Windows signing host after building the unsigned candidate.
# This script intentionally refuses to generate or substitute a certificate.
param([string]$Exe = 'bundles-v103/diakitw-win32-x64/diakitw.exe')
$ErrorActionPreference = 'Stop'
if ($env:DIakitw_SIGNING_THUMBPRINT -notmatch '^[0-9A-Fa-f]{40}$') { throw 'Trusted signing identity thumbprint required' }
$thumbprint = $env:DIakitw_SIGNING_THUMBPRINT.ToUpperInvariant()
$cert = Get-Item "Cert:\LocalMachine\My\$thumbprint" -ErrorAction SilentlyContinue
if (-not $cert -or -not $cert.HasPrivateKey) { throw 'Trusted signing certificate with private key unavailable' }
if ($cert.Subject -eq $cert.Issuer -or $cert.NotBefore -gt (Get-Date) -or $cert.NotAfter -lt (Get-Date)) { throw 'Signing certificate is self-signed or expired' }
if (-not ($cert.EnhancedKeyUsageList | Where-Object { $_.FriendlyName -eq 'Code Signing' -and $_.ObjectId -eq '1.3.6.1.5.5.7.3.3' })) { throw 'Code Signing EKU required' }
$chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
$chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Online
$chain.ChainPolicy.RevocationFlag = [System.Security.Cryptography.X509Certificates.X509RevocationFlag]::EntireChain
if (-not $chain.Build($cert)) { throw 'Signing certificate chain is not trusted' }
if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) { throw 'EXE missing' }
$signTool = (Get-Command signtool.exe -ErrorAction Stop).Source
& $signTool sign /fd SHA256 /sha1 $thumbprint /sm /tr http://timestamp.digicert.com /td SHA256 $Exe
if ($LASTEXITCODE -ne 0) { throw 'Authenticode signing failed' }
& $signTool verify /pa /all /v $Exe
if ($LASTEXITCODE -ne 0) { throw 'Authenticode verify /pa failed' }
Write-Output 'Authenticode verified; SmartScreen reputation is not guaranteed.'
