# ============================================================
# PHPShift Automated Setup
# Fully unattended: no dialog boxes, no wizard clicks, no prompts.
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # speeds up + quiets Invoke-WebRequest/choco output

# ------------------------------------------------------------
# 0. Self-elevate if not already Administrator (only one UAC
#    click, then the rest of the script never prompts again).
# ------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Elevation required - relaunching as Administrator..." -ForegroundColor Yellow
    $psi = @{
        FilePath     = "powershell.exe"
        ArgumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Verb         = "RunAs"
    }
    try {
        Start-Process @psi
    } catch {
        Write-Warning "Elevation was cancelled. PHPShift setup cannot continue without Administrator rights."
        Start-Sleep -s 3
    }
    Exit
}

Write-Host "Starting PHPShift Automation Setup..." -ForegroundColor Cyan

# ------------------------------------------------------------
# Helper: reliably refresh the current session's PATH / env
# vars after Chocolatey installs something new, with retries.
# ------------------------------------------------------------
Function Update-SessionPath {
    $chocoProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if (Test-Path $chocoProfile) {
        Import-Module $chocoProfile -Force
        refreshenv | Out-Null
    } else {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
}

Function Wait-ForCommand {
    param([string]$Command, [int]$TimeoutSeconds = 30)
    $elapsed = 0
    while (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        if ($elapsed -ge $TimeoutSeconds) { return $false }
        Update-SessionPath
        Start-Sleep -s 2
        $elapsed += 2
    }
    return $true
}

# ------------------------------------------------------------
# 1. Install Chocolatey if not present
# ------------------------------------------------------------
Write-Host "Checking Chocolatey..." -ForegroundColor Cyan
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "   -> Installing Chocolatey..." -ForegroundColor Yellow
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Update-SessionPath
    Write-Host "   -> Chocolatey installed." -ForegroundColor Green
} else {
    Write-Host "   -> Chocolatey is already installed." -ForegroundColor Green
}

# Make Chocolatey itself never prompt for confirmation again on this machine
choco feature enable -n=allowGlobalConfirmation -y | Out-Null

Update-SessionPath

# ------------------------------------------------------------
# 2. Install System Requirements - each with an explicit
#    "--override-arguments" silent switch set for the *native*
#    installer underneath (this is the part that was actually
#    causing the click-through wizards, not the choco -y flag).
# ------------------------------------------------------------
Function Install-Software {
    param(
        [string]$Package,
        [string]$Name,
        [string]$SilentArgs = $null   # native installer silent switches, if we need to override
    )
    Write-Host "Checking $Name..."

    $check = choco list --local-only 2>$null | Select-String "^$Package "
    if ($check) {
        Write-Host "   -> $Name is already installed." -ForegroundColor Green
        return
    }

    Write-Host "   -> Installing $Name..." -ForegroundColor Yellow

    $chocoArgs = @(
        "install", $Package,
        "-y",
        "--no-progress",
        "--limit-output",
        "--acceptlicense"
    )
    if ($SilentArgs) {
        $chocoArgs += "--override-arguments"
        $chocoArgs += "--install-arguments=`"$SilentArgs`""
    }

    & choco @chocoArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   -> $Name installed successfully." -ForegroundColor Green
    } else {
        Write-Warning "   -> $Name install exited with code $LASTEXITCODE. Check $env:ChocolateyInstall\logs\chocolatey.log"
    }
    Update-SessionPath
}

# Native silent-install switches for the installer technology each package actually uses:
#   Python official installer            -> /quiet InstallAllUsers=1 PrependPath=1
#   XAMPP (Bitrock InstallBuilder)        -> --mode unattended --unattendedmodeui minimal
#   Composer (Inno Setup based)           -> /VERYSILENT /SUPPRESSMSGBOXES /SP- /NORESTART
#   Git for Windows (Inno Setup)          -> /VERYSILENT /SUPPRESSMSGBOXES /SP- /NORESTART /NOCANCEL /NOICONS
#   VS Code (Inno Setup)                  -> /VERYSILENT /SUPPRESSMSGBOXES /SP- /NORESTART /MERGETASKS=!runcode,!desktopicon

Install-Software -Package "python311" -Name "Python 3.11" -SilentArgs "/quiet InstallAllUsers=1 PrependPath=1"
Install-Software -Package "xampp-81"  -Name "XAMPP (PHP 8.1)" -SilentArgs "--mode unattended --unattendedmodeui minimal"
Install-Software -Package "git"       -Name "Git" -SilentArgs "/VERYSILENT /SUPPRESSMSGBOXES /SP- /NORESTART /NOCANCEL /NOICONS"
Install-Software -Package "vscode"    -Name "VS Code" -SilentArgs "/VERYSILENT /SUPPRESSMSGBOXES /SP- /NORESTART /MERGETASKS=!runcode,!desktopicon"
Install-Software -Package "composer"  -Name "Composer" -SilentArgs "/VERYSILENT /SUPPRESSMSGBOXES /SP- /NORESTART"

Update-SessionPath

# ------------------------------------------------------------
# 3. Install Python Modules
# ------------------------------------------------------------
Write-Host "Installing required Python modules..." -ForegroundColor Cyan
if (Wait-ForCommand -Command "pip" -TimeoutSeconds 30) {
    python -m pip install --upgrade pip --quiet --disable-pip-version-check
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "   -> Failed to upgrade pip (exit code $LASTEXITCODE)."
    }

    python -m pip install phpshift --quiet --disable-pip-version-check
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   -> Python modules installed." -ForegroundColor Green
    } else {
        Write-Warning "   -> Failed to install 'phpshift' via pip (exit code $LASTEXITCODE)."
    }
} else {
    Write-Warning "   -> pip did not become available on PATH in time. Skipping Python module install."
}

# ------------------------------------------------------------
# 4. Decode and Import VS Code Profile
# ------------------------------------------------------------
Write-Host "Applying VS Code Profile..." -ForegroundColor Cyan

# The builder script will automatically inject the base64 string here
$base64Profile = "__PROFILE_BASE64__"

$profilePath = "$env:TEMP\vsetup.code-profile"
if (Wait-ForCommand -Command "code" -TimeoutSeconds 30) {
    try {
        $bytes = [System.Convert]::FromBase64String($base64Profile)
        [System.IO.File]::WriteAllBytes($profilePath, $bytes)

        & code --install-profile $profilePath 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   -> Profile 'vsetup' successfully imported." -ForegroundColor Green
        } else {
            Write-Warning "   -> VS Code returned exit code $LASTEXITCODE while importing the profile."
        }
    } catch {
        Write-Warning "   -> Could not import VS Code profile: $($_.Exception.Message)"
    } finally {
        Remove-Item $profilePath -ErrorAction SilentlyContinue
    }
} else {
    Write-Warning "   -> 'code' did not become available on PATH in time. Skipping profile import."
}

Write-Host "PHPShift v1.0.0 Installation Complete!" -ForegroundColor Cyan
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
