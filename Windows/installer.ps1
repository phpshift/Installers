param(
    [string]$Step
)

# STRICT UNATTENDED MODE
$ConfirmPreference = 'None'
$ProgressPreference = 'SilentlyContinue'

# 1. Helper to permanently write a directory to the Windows Registry System PATH
Function Add-PermanentMachinePath {
    param([string]$Dir)
    
    if (-not (Test-Path $Dir)) { 
        Write-Output "WARNING: Directory not found, could not add to permanent PATH: $Dir"
        return 
    }
    
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    
    if ($machinePath -notmatch [regex]::Escape($Dir)) {
        $newPath = $machinePath
        if (-not $newPath.EndsWith(";")) { $newPath += ";" }
        $newPath += $Dir
        
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Output "Permanently secured system PATH: $Dir"
    } else {
        Write-Output "Directory already exists in system PATH: $Dir"
    }
}

Function Update-SessionPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path","User")
    
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
    
    foreach ($p in $hardcodedPaths) {
        if ($newPath -notmatch [regex]::Escape($p) -and (Test-Path $p)) {
            $newPath += ";$p"
        }
    }
    
    $env:Path = $newPath
}

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
        # Explicitly force the target directory so our PATH variables never fail
        choco install python311 -y --force --force-dependencies --no-progress --acceptlicense --override-arguments --install-arguments="/quiet InstallAllUsers=1 PrependPath=1 TargetDir=C:\Python311"
        
        Write-Output "Forcing Python directories into permanent System PATH..."
        Add-PermanentMachinePath "C:\Python311"
        Add-PermanentMachinePath "C:\Python311\Scripts"
    }
    "xampp" { 
        Write-Output "Installing XAMPP (PHP 8.1.25)..."
        choco install xampp-81 -y --force --force-dependencies --no-progress --acceptlicense --override-arguments --install-arguments="--mode unattended --unattendedmodeui minimal"
        
        Write-Output "Forcing PHP directory into permanent System PATH..."
        Add-PermanentMachinePath "C:\xampp\php"
    }
    "git" { 
        Write-Output "Installing Git..."
        choco install git -y --force --force-dependencies --no-progress --acceptlicense 
    }
    "vscode" { 
        Write-Output "Installing Visual Studio Code..."
        choco install vscode -y --force --force-dependencies --no-progress --acceptlicense --override-arguments --install-arguments="/VERYSILENT /SUPPRESSMSGBOXES /SP- /NORESTART /MERGETASKS=!runcode,!desktopicon"
    }
    "composer" { 
        Write-Output "Installing Composer..."
        choco install composer -y --force --force-dependencies --no-progress --acceptlicense 
    }
    "pip" {
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
}
