# probe1.ps1 - AIOS Windows dry run, stage 2: install the client-facing prerequisite stack
# exactly the way day-one-install.md tells a client to, and record what actually happens.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
New-Item -ItemType Directory -Force -Path 'C:\aios' | Out-Null
Start-Transcript -Path 'C:\aios\probe1.log' -Append | Out-Null

function Section($t) { Write-Host ""; Write-Host ("=== " + $t + " ===") }

Section "environment"
$os = Get-CimInstance Win32_OperatingSystem
"Caption      : $($os.Caption)"
"Version      : $($os.Version)  Build $($os.BuildNumber)"
"Arch (env)   : $env:PROCESSOR_ARCHITECTURE"
"RAM (GB)     : {0:N1}" -f ($os.TotalVisibleMemorySize / 1MB)
"PowerShell   : $($PSVersionTable.PSVersion)"
try { "winget       : $(winget --version)" } catch { "winget       : NOT PRESENT - $($_.Exception.Message)" }

Section "winget source refresh"
winget source update 2>&1 | Out-String | Write-Host

# day-one-install.md Section B step 1: Git and Node, installed live on the call.
Section "install Git (day-one: winget install --id Git.Git -e --source winget)"
winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-String | Write-Host

Section "install Node LTS (day-one: winget install --id OpenJS.NodeJS.LTS -e)"
winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-String | Write-Host

# day-one-install.md Section A step 1: VS Code.
Section "install VS Code"
winget install --id Microsoft.VisualStudioCode -e --source winget --accept-source-agreements --accept-package-agreements --silent --override '/VERYSILENT /NORESTART /MERGETASKS="!runcode,addcontextmenufiles,addcontextmenufolders,addtopath"' 2>&1 | Out-String | Write-Host

Section "refresh PATH in this session"
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$machinePath;$userPath"
"PATH entries: $($env:Path.Split(';').Count)"

Section "what got installed, and for which architecture"
foreach ($exe in @('git', 'node', 'npm', 'code', 'bash')) {
    $c = Get-Command $exe -ErrorAction SilentlyContinue
    if ($c) { "{0,-6} -> {1}" -f $exe, $c.Source } else { "{0,-6} -> NOT FOUND" -f $exe }
}
try { "git version  : $(git --version)" } catch { "git version  : FAILED" }
try { "node version : $(node --version)" } catch { "node version : FAILED" }
try { "node arch    : $(node -p 'process.arch')" } catch { "node arch    : FAILED" }
try { "npm version  : $(npm --version)" } catch { "npm version  : FAILED" }

# Native vs emulated matters on Arm64: an x64 binary here means the client is running under emulation.
Section "binary architecture check"
function Get-ExeArch($path) {
    try {
        $fs = [IO.File]::OpenRead($path)
        $br = New-Object IO.BinaryReader($fs)
        $fs.Position = 0x3C
        $peOff = $br.ReadInt32()
        $fs.Position = $peOff + 4
        $machine = $br.ReadUInt16()
        $fs.Close()
        switch ($machine) {
            0x8664 { 'x64' }
            0x014c { 'x86' }
            0xAA64 { 'ARM64' }
            default { ('0x{0:X}' -f $machine) }
        }
    } catch { "unreadable: $($_.Exception.Message)" }
}
foreach ($exe in @('git', 'node', 'code')) {
    $c = Get-Command $exe -ErrorAction SilentlyContinue
    if ($c) { "{0,-6} {1,-8} {2}" -f $exe, (Get-ExeArch $c.Source), $c.Source }
}

Section "git credential helpers present (keyed-switch detect_helper surface)"
try {
    $ep = git --exec-path
    "git --exec-path: $ep"
    foreach ($h in @('git-credential-manager.exe', 'git-credential-manager-core.exe', 'git-credential-wincred.exe', 'git-credential-store.exe')) {
        $p = Join-Path $ep $h
        "{0,-36} {1}" -f $h, $(if (Test-Path $p) { 'PRESENT' } else { 'absent' })
    }
    "on PATH: git-credential-manager = " + $(if (Get-Command git-credential-manager -ErrorAction SilentlyContinue) { 'yes' } else { 'no' })
} catch { "git exec-path probe failed: $($_.Exception.Message)" }

Section "install Claude Code CLI"
npm install -g @anthropic-ai/claude-code 2>&1 | Out-String | Write-Host
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + (Join-Path $env:APPDATA 'npm')
try { "claude version: $(claude --version)" } catch { "claude version: FAILED - $($_.Exception.Message)" }

'probe1-done' | Out-File 'C:\aios\PROBE1_DONE' -Encoding ascii
Stop-Transcript | Out-Null
