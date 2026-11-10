# Usage: .\bin\install.ps1 [project_folder]
# Windows counterpart of install.sh. Records the install and project folders
# (via setup.ps1), adds ASM_Template\bin to your PATH, and checks the tools.
$asmRoot = Split-Path -Parent $PSScriptRoot
Push-Location $asmRoot
& "$PSScriptRoot\setup.ps1" @args
$ok = $?
Pop-Location
if (-not $ok) { exit 1 }

# Add bin to the user PATH once
$bin = "$asmRoot\bin"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ';') -notcontains $bin) {
    [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ";$bin"), "User")
    Write-Host "Added $bin to your PATH."
}

# Check the tools
$arm = $env:PROCESSOR_ARCHITECTURE -eq "ARM64"
Write-Host ""
Write-Host ("Detected: " + $(if ($arm) { "Windows on Arm (native ARM64 template: bin\WindowsArmProject.ps1)" } else { "Windows x64 (template: bin\WindowsProject.ps1)" }))
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$component = if ($arm) { "Microsoft.VisualStudio.Component.VC.Tools.ARM64" } else { "Microsoft.VisualStudio.Component.VC.Tools.x86.x64" }
$vs = if (Test-Path $vswhere) { & $vswhere -latest -products * -requires $component -property installationPath } else { $null }
if ($vs) { Write-Host "OK      Visual Studio C++ tools: $vs" }
else {
    Write-Host "MISSING Visual Studio Build Tools with C++ ($component)"
    Write-Host "        https://visualstudio.microsoft.com/downloads/  (Tools for Visual Studio > Build Tools)"
}
if (-not $arm) {
    if (Get-Command nasm -ErrorAction SilentlyContinue) { Write-Host "OK      nasm" }
    else {
        Write-Host "MISSING nasm: https://www.nasm.us/pub/nasm/releasebuilds/"
    }
}
Write-Host ""
Write-Host "Open a new PowerShell window so PATH and the folder variables take effect."
