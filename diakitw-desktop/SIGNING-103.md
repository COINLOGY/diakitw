# Windows 1.0.3 candidate signing gate

The Linux CI job creates **unsigned portable candidates only**. Its ZIP must not be described as Authenticode-signed. No release or feed is changed by this branch.

On a controlled Windows signing host, use the existing publisher's trusted code-signing certificate in `Cert:\LocalMachine\My`; set `DIakitw_SIGNING_THUMBPRINT` to its 40-hex-character thumbprint in the host's protected environment. Build and normalize the Windows EXE first, then run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/sign-windows-v103.ps1`. The script refuses missing identity/private key, a self-signed or expired certificate, absent Code Signing EKU, an untrusted/revoked chain, signing failure, or `signtool verify /pa` failure. It does not create a certificate. **Repackage and re-hash the ZIP after signing**; the unsigned candidate's manifest and digest must not be reused. The normal unsigned bundle verification must run before signing (it deliberately checks that no certificate is present).

No trusted signing identity was provided in this worktree, so signed Windows artifact and SmartScreen acceptance remain unverified. Authenticode alone does not guarantee SmartScreen reputation. Target Windows and Linux installation/runtime checks remain separate from archive checks.
