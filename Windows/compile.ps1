Write-Host "Preparing PHPShift Installer Build..." -ForegroundColor Cyan

# Define file paths
$profileFile = ".\vsetup.code-profile"
$templateFile = ".\installer.ps1"
$tempScript = ".\temp.ps1"
$outputExe = ".\phpshift-v1.0.0.exe"
$iconFile = ".\phpshift.ico"

# 1. Ensure required files exist
if (!(Test-Path $profileFile)) { Write-Error "Missing $profileFile"; exit }
if (!(Test-Path $templateFile)) { Write-Error "Missing $templateFile"; exit }

# 2. Read the VS Code profile and convert to Base64
Write-Host "Encoding VS Code profile..."
$profileBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $profileFile).Path)
$base64String = [System.Convert]::ToBase64String($profileBytes)

# 3. Inject the Base64 string into the template
Write-Host "Injecting profile into script template..."
$templateContent = Get-Content -Raw -Path $templateFile
$finalScriptContent = $templateContent -replace "__PROFILE_BASE64__", $base64String

# Save the ready-to-compile script
$finalScriptContent | Out-File -FilePath $tempScript -Encoding utf8

# 4. Compile the script using ps2exe
Write-Host "Compiling to $outputExe..." -ForegroundColor Yellow

# Compile with or without the icon depending on if the file is present
if (Test-Path $iconFile) {
    Write-Host "   -> Custom icon found. Applying to executable..." -ForegroundColor Cyan
    Invoke-ps2exe -inputFile $tempScript -outputFile $outputExe -requireAdmin -noConsole -iconFile $iconFile
} else {
    Write-Warning "   -> icon.ico not found. Compiling with default Windows executable icon."
    Invoke-ps2exe -inputFile $tempScript -outputFile $outputExe -requireAdmin -noConsole
}

# 5. Clean up the temporary script
Remove-Item $tempScript -Force
Write-Host "Build Complete! $outputExe is ready." -ForegroundColor Green