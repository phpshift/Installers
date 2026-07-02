# Require Administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run this installer as Administrator."
    Start-Sleep -s 3
    Exit
}

Write-Host "Starting PHPShift Automation Setup..." -ForegroundColor Cyan

# 1. Install Chocolatey if not present
Write-Host "Checking Chocolatey..." -ForegroundColor Cyan
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "   -> Installing Chocolatey..." -ForegroundColor Yellow
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Host "   -> Chocolatey installed." -ForegroundColor Green
} else {
    Write-Host "   -> Chocolatey is already installed." -ForegroundColor Green
}

# Refresh PATH to include Chocolatey
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Function Install-Software {
    param([string]$package, [string]$name)
    Write-Host "Checking $name..."
    
    # Check if already installed
    $check = choco list --local-only 2>$null | Select-String $package
    if ($check) {
        Write-Host "   -> $name is already installed." -ForegroundColor Green
    } else {
        Write-Host "   -> Installing $name..." -ForegroundColor Yellow
        choco install $package -y --no-progress 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   -> $name installed successfully." -ForegroundColor Green
        } else {
            Write-Host "   -> Failed to install $name via Chocolatey." -ForegroundColor Yellow
        }
    }
}

# 2. Install System Requirements
Install-Software -package "python311" -name "Python 3.11"
Install-Software -package "xampp-81" -name "XAMPP (PHP 8.1)"
Install-Software -package "composer" -name "Composer"
Install-Software -package "git" -name "Git"
Install-Software -package "vscode" -name "VS Code"

# 3. Force Environment PATH Refresh
Write-Host "Refreshing Environment Variables..." -ForegroundColor Cyan
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 4. Install Python Modules
Write-Host "Installing required Python modules..." -ForegroundColor Cyan
try {
    pip install --upgrade pip
    pip install phpshift
    Write-Host "   -> Python modules installed." -ForegroundColor Green
} catch {
    Write-Warning "   -> Failed to install Python modules. Make sure Python is properly installed."
}

# 5. Decode and Import VS Code Profile
Write-Host "Applying VS Code Profile..." -ForegroundColor Cyan

# The builder script will automatically inject the base64 string here
$base64Profile = "__PROFILE_BASE64__"

$profilePath = "$env:TEMP\vsetup.code-profile"
try {
    # Decode from Base64 back to a file
    $bytes = [System.Convert]::FromBase64String($base64Profile)
    [System.IO.File]::WriteAllBytes($profilePath, $bytes)

    # Execute VS Code profile import
    code --install-profile $profilePath
    Write-Host "   -> Profile 'vsetup' successfully imported." -ForegroundColor Green
} catch {
    Write-Warning "   -> Could not launch VS Code to import profile. Ensure VS Code is in your PATH."
}

# Cleanup Temp File
Remove-Item $profilePath -ErrorAction SilentlyContinue

Write-Host "PHPShift v1.0.0 Installation Complete!" -ForegroundColor Cyan
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')