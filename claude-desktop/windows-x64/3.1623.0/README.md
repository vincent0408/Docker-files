# Claude Desktop 3.1623.0 for Windows (x64)

Anthropic's official installer for the Claude desktop app, as served by
[claude.com/download](https://claude.com/download) for 64-bit Windows on
2026-10-21.

| File | Version | Size |
|---|---|---|
| `Claude-Setup-x64.exe` | 3.1623.0 | 268 MB |

Downloaded unchanged from
`https://downloads.claude.ai/releases/win32/x64/3.1623.0/Claude-e751f9d5249da803676835a68a9b15463ec5b1d7.exe`
and renamed. It matches the MD5 that the download server publishes for that
file, and its Authenticode signature is valid: signed by `Anthropic, PBC`
(certificate issued by DigiCert), timestamped 2026-10-20.

## Download

In a browser, open the file on GitHub and click the download button
(**Download raw file**), or use this link:
<https://github.com/vincent0408/Docker-files/raw/master/claude-desktop/windows-x64/3.1623.0/Claude-Setup-x64.exe>

With Git LFS, to fetch only this file:

```bash
git lfs install
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/vincent0408/Docker-files.git
cd Docker-files && git lfs pull --include "claude-desktop/**"
```

A ~134-byte `Claude-Setup-x64.exe` is still an LFS pointer: run the
`git lfs pull` again. Don't use GitHub's **Download ZIP**; it contains the
pointer, not the installer.

## Verify

In PowerShell, in the folder with the installer:

```powershell
(Get-FileHash .\Claude-Setup-x64.exe).Hash
# must be 8B78E8F1A6119BA99445E5204D34DFEE5119CA7B314D2E0A4FD3C7FE44C5B525

Get-AuthenticodeSignature .\Claude-Setup-x64.exe | Format-List Status, SignerCertificate
# Status must be Valid, signer CN=Anthropic, PBC
```

Don't run the file if either check fails.

## Install

Double-click `Claude-Setup-x64.exe`. Installing without admin rights works,
but according to Anthropic's deployment guide, Cowork on desktop is then not
available.

Claude Desktop updates itself after it's installed, so this version is only
the starting point. For deploying across many machines (Intune, SCCM, Group
Policy), Anthropic provides an MSIX package instead; see
[Deploy Claude Desktop for Windows](https://support.claude.com/en/articles/12622703-deploy-claude-desktop-for-windows).

## Update

Newer versions are not in this folder. Get the latest from
[claude.com/download](https://claude.com/download), or ask for it to be added
here as a new folder.
