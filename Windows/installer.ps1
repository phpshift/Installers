# Require Administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run this installer as Administrator."
    Start-Sleep -s 3
    Exit
}

Write-Host "Starting PHPShift Automation Setup..." -ForegroundColor Cyan

Function Install-Software {
    param([string]$id, [string]$name, [string]$version = "")
    Write-Host "Checking $name..."
    $check = winget list --id $id --exact 2>$null
    if ($check -match $id) {
        Write-Host "   -> $name is already installed." -ForegroundColor Green
    } else {
        Write-Host "   -> Installing $name..." -ForegroundColor Yellow
        $versionParam = if ($version) { "--version $version" } else { "" }
        Invoke-Expression "winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements $versionParam"
    }
}

# 1. Install System Requirements
Install-Software -id "Python.Python.3.11" -name "Python & PIP"
Install-Software -id "ApacheFriends.Xampp.8.1" -name "XAMPP (PHP 8.1)" -version "8.1.25"
Install-Software -id "getcomposer.Composer" -name "Composer"
Install-Software -id "Git.Git" -name "Git"
Install-Software -id "Microsoft.VisualStudioCode" -name "VS Code"

# 2. Force Environment PATH Refresh
Write-Host "Refreshing Environment Variables..." -ForegroundColor Cyan
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# 3. Install Python Modules
Write-Host "Installing required Python modules..." -ForegroundColor Cyan
try {
    pip install clight gits
    Write-Host "   -> Python modules installed." -ForegroundColor Green
} catch {
    Write-Warning "   -> PIP might not be in PATH yet. Restart your terminal later."
}

# 4. Decode and Import VS Code Profile
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