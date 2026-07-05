param(
    [string]$Step,
    [string]$ProfilePath
)

# STRICT UNATTENDED MODE
$ConfirmPreference = 'None'
$ProgressPreference = 'SilentlyContinue'

Function Update-SessionPath {
    # Dynamically pull the latest PATH straight from the registry to ensure pip/choco/code are always found
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User") + ";C:\xampp\php;C:\tools\xampp\php"
}

Update-SessionPath

switch ($Step) {
    "choco-init" {
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Output "Downloading and installing Chocolatey Package Manager..."
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        }
        else {
            Write-Output "Chocolatey is already installed. Proceeding..."
        }
    }
    "python" { 
        choco install python311 -y --no-progress --limit-output --acceptlicense 
    }
    "xampp" { 
        choco install xampp-81 -y --no-progress --limit-output --acceptlicense 
    }
    "git" { 
        choco install git -y --no-progress --limit-output --acceptlicense 
    }
    "vscode" { 
        choco install vscode -y --no-progress --limit-output --acceptlicense 
    }
    "composer" { 
        choco install composer -y --no-progress --limit-output --acceptlicense 
    }
    "pip" {
        Write-Output "Upgrading PIP..."
        python -m pip install --upgrade pip --disable-pip-version-check
        Write-Output "Installing PHPShift Modules..."
        python -m pip install clight phpshift --disable-pip-version-check
    }
    "profile" {
        if (Test-Path $ProfilePath) {
            Write-Output "Applying custom VS Code settings..."
            code --install-profile $ProfilePath
        }
        else {
            Write-Output "Warning: Profile file missing!"
        }
    }
}