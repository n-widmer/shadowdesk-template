# stage1.ps1 - first-logon bootstrap for the AIOS Windows dry run VM.
# Goal: get a reliable SSH control channel up, then install UTM guest tools.
# Everything after this is driven from the Mac over SSH.

$ErrorActionPreference = 'Continue'
$media = Split-Path -Parent $MyInvocation.MyCommand.Path
New-Item -ItemType Directory -Force -Path 'C:\aios' | Out-Null
Start-Transcript -Path 'C:\aios\stage1.log' -Append | Out-Null

function Log($m) { Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) }

Log "stage1 starting. media=$media"
Log ("OS: " + (Get-CimInstance Win32_OperatingSystem).Caption + " " + (Get-CimInstance Win32_OperatingSystem).Version)
Log ("Arch: " + $env:PROCESSOR_ARCHITECTURE)

# --- keep the VM awake -------------------------------------------------------
powercfg /change standby-timeout-ac 0
powercfg /change monitor-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

# --- virtio drivers ----------------------------------------------------------
# WinPE driver injection depends on the setup ISO landing on E:, which is not
# guaranteed. Install them again from whatever letter the media actually got.
$driverRoot = Join-Path (Split-Path -Parent $media) 'Drivers'
foreach ($d in @('NetKVM\w10\ARM64', 'vioserial\w10\ARM64', 'viostor\w10\ARM64', 'Balloon\w10\ARM64')) {
    $p = Join-Path $driverRoot $d
    if (Test-Path $p) {
        Log "pnputil installing $p"
        pnputil /add-driver "$p\*.inf" /install | Out-String | Write-Host
    } else {
        Log "driver path missing: $p"
    }
}
Start-Sleep -Seconds 5

# --- wait for network --------------------------------------------------------
$net = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        if (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction Stop) { $net = $true; break }
    } catch { }
    Start-Sleep -Seconds 5
}
Log "network reachable: $net"
Get-NetAdapter | Format-Table -AutoSize | Out-String | Write-Host

# --- OpenSSH server ----------------------------------------------------------
# Install from the bundled zip first: it works with no network at all, which is
# the case this whole bootstrap has to survive.
$sshInstalled = $false
$zip = Join-Path $media 'OpenSSH-ARM64.zip'
if (Test-Path $zip) {
    try {
        Log "installing bundled Win32-OpenSSH (ARM64)"
        Expand-Archive -Path $zip -DestinationPath 'C:\Program Files' -Force
        & 'C:\Program Files\OpenSSH-ARM64\install-sshd.ps1'
        $env:Path += ';C:\Program Files\OpenSSH-ARM64'
        $sshInstalled = $true
    } catch {
        Log ("bundled OpenSSH install failed: " + $_.Exception.Message)
    }
}

if (-not $sshInstalled) {
    try {
        $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' -ErrorAction Stop
        Log ("OpenSSH.Server capability state: " + $cap.State)
        if ($cap.State -ne 'Installed') {
            Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop | Out-Null
        }
        $sshInstalled = $true
    } catch {
        Log ("Add-WindowsCapability failed: " + $_.Exception.Message)
    }
}

if ($sshInstalled) {
    Set-Service -Name sshd -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service sshd -ErrorAction SilentlyContinue
    Log ("sshd status: " + (Get-Service sshd -ErrorAction SilentlyContinue).Status)

    # PowerShell as the default SSH shell so remote commands behave predictably.
    New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
    New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
        -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force | Out-Null

    # Public key auth for the admin account.
    $keySrc = Join-Path $media 'authorized_keys'
    $progData = 'C:\ProgramData\ssh'
    New-Item -ItemType Directory -Force -Path $progData | Out-Null
    $adminKeys = Join-Path $progData 'administrators_authorized_keys'
    Copy-Item $keySrc $adminKeys -Force
    icacls $adminKeys /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null

    $userSsh = Join-Path $env:USERPROFILE '.ssh'
    New-Item -ItemType Directory -Force -Path $userSsh | Out-Null
    Copy-Item $keySrc (Join-Path $userSsh 'authorized_keys') -Force

    New-NetFirewallRule -Name 'sshd-aios' -DisplayName 'OpenSSH Server (aios)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null

    Restart-Service sshd -ErrorAction SilentlyContinue
    Log ("sshd final status: " + (Get-Service sshd -ErrorAction SilentlyContinue).Status)
    'ssh-ready' | Out-File 'C:\aios\SSH_READY' -Encoding ascii
}

# --- UTM guest tools (virtio drivers, SPICE agent, QEMU guest agent) ---------
try {
    $gt = Get-ChildItem -Path (Split-Path -Parent $media) -Filter 'utm-guest-tools-*.exe' -ErrorAction Stop | Select-Object -First 1
    if ($gt) {
        Log ("installing guest tools: " + $gt.FullName)
        $p = Start-Process -FilePath $gt.FullName -ArgumentList '/S' -PassThru
        if (-not $p.WaitForExit(420000)) {
            Log "guest tools installer still running after 7 min, leaving it"
        } else {
            Log ("guest tools exit code: " + $p.ExitCode)
        }
    } else {
        Log "guest tools installer not found on media"
    }
} catch {
    Log ("guest tools install failed: " + $_.Exception.Message)
}

'stage1-done' | Out-File 'C:\aios\STAGE1_DONE' -Encoding ascii
Log "stage1 complete"
Stop-Transcript | Out-Null
