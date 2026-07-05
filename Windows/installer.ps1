param(
    [string]$Step,
    [string]$ProfilePath
)

# STRICT UNATTENDED MODE
$ConfirmPreference = 'None'
$ProgressPreference = 'SilentlyContinue'

# 1. Helper to permanently write a directory to the Windows Registry System PATH
Function Add-PermanentMachinePath {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { return }
    
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    
    # Only add it if it doesn't already exist in the permanent registry
    if ($machinePath -notmatch [regex]::Escape($Dir)) {
        $newPath = $machinePath
        if (-not $newPath.EndsWith(";")) { $newPath += ";" }
        $newPath += $Dir
        
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Output "Permanently secured system PATH: $Dir"
    }
}

Function Update-SessionPath {
    # Pull the latest PATH straight from the Windows Registry for the active session
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Define the exact locations where our software installs
    $hardcodedPaths = @(
        "C:\ProgramData\chocolatey\bin",
        "C:\Python311",
        "C:\Python311\Scripts",
        "C:\Program Files\Git\cmd",
        "C:\Program Files\Microsoft VS Code\bin",
        "$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code\bin",
        "C:\xampp\php",
        "C:\tools\xampp\php",
        "$env:ProgramData\ComposerSetup\bin"
    )
    
    $newPath = "$machinePath;$userPath"
    
    # Force these paths into the current session if they exist
    foreach ($p in $hardcodedPaths) {
        if ($newPath -notmatch [regex]::Escape($p) -and (Test-Path $p)) {
            $newPath += ";$p"
        }
    }
    
    $env:Path = $newPath
}

# Run path update at the start of every step
Update-SessionPath

switch ($Step) {
    "choco-init" {
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Output "Downloading and installing Chocolatey Package Manager..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        } else {
            Write-Output "Chocolatey is already installed. Proceeding..."
        }
    }
    "python" { 
        Write-Output "Installing Python 3.11..."
        choco install python311 -y --force --force-dependencies --no-progress --acceptlicense 
        
        Write-Output "Forcing Python directories into permanent System PATH..."
        Add-PermanentMachinePath "C:\Python311"
        Add-PermanentMachinePath "C:\Python311\Scripts"
    }
    "xampp" { 
        Write-Output "Installing XAMPP (PHP 8.1.25)..."
        choco install xampp-81 -y --force --force-dependencies --no-progress --acceptlicense 
        
        Write-Output "Forcing PHP directory into permanent System PATH..."
        Add-PermanentMachinePath "C:\xampp\php"
    }
    "git" { 
        Write-Output "Installing Git..."
        choco install git -y --force --force-dependencies --no-progress --acceptlicense 
    }
    "vscode" { 
        Write-Output "Installing Visual Studio Code..."
        choco install vscode -y --force --force-dependencies --no-progress --acceptlicense 
    }
    "composer" { 
        Write-Output "Installing Composer..."
        choco install composer -y --force --force-dependencies --no-progress --acceptlicense 
    }
    "pip" {
        # Force a session path update right before we try to use Python
        Update-SessionPath 
        Write-Output "Checking Python accessibility..."
        
        if (Get-Command python -ErrorAction SilentlyContinue) {
            Write-Output "Upgrading PIP..."
            python -m pip install --upgrade pip --force-reinstall --disable-pip-version-check
            Write-Output "Installing PHPShift Modules..."
            python -m pip install clight phpshift --force-reinstall --disable-pip-version-check
        } else {
            Write-Output "CRITICAL ERROR: Python is not accessible in the current environment path."
        }
    }
    "profile" {
        # Force a session path update right before we try to use VS Code
        Update-SessionPath 
        
        if (Test-Path $ProfilePath) {
            Write-Output "Checking VS Code accessibility..."
            if (Get-Command code -ErrorAction SilentlyContinue) {
                Write-Output "Applying custom VS Code settings..."
                code --install-profile $ProfilePath
            } else {
                Write-Output "CRITICAL ERROR: VS Code ('code') is not accessible in the current environment path."
            }
        } else {
            Write-Output "CRITICAL ERROR: Profile file missing at $ProfilePath"
        }
    }
}