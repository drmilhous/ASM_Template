# Locates the Visual Studio C++ tools and saves the result to ~/.asm_template_tools.json
# so builds don't have to search again. Usage: findTools.ps1 [-Force]
param([switch]$Force)
$saved = "$env:USERPROFILE\.asm_template_tools.json"
# Use the real machine type. A PowerShell started from an x64-emulated parent (for example
# from an MSYS2 shell) reports AMD64 in PROCESSOR_ARCHITECTURE and in .NET, even on an ARM64
# PC, which would pick the x64 tools. The registry holds the machine's true architecture.
$machine = try { (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name PROCESSOR_ARCHITECTURE -ErrorAction Stop).PROCESSOR_ARCHITECTURE } catch { $env:PROCESSOR_ARCHITECTURE }
$arm = ($machine -eq "ARM64") -or ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") -or ($env:PROCESSOR_ARCHITEW6432 -eq "ARM64")
$arch = if ($arm) { "arm64" } else { "x64" }
$component = if ($arm) { "Microsoft.VisualStudio.Component.VC.Tools.ARM64" } else { "Microsoft.VisualStudio.Component.VC.Tools.x86.x64" }
$batName = if ($arm) { "vcvarsarm64.bat" } else { "vcvars64.bat" }

if (-not $Force -and (Test-Path $saved)) {
  $info = Get-Content $saved -Raw | ConvertFrom-Json
  if ($info.arch -eq $arch -and (Test-Path $info.vcvars)) { return $info }
}
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = if (Test-Path $vswhere) { & $vswhere -latest -products * -requires $component -property installationPath } else { $null }
if (-not $vsPath) {
  Write-Host "Visual Studio C++ tools not found (need component $component)."
  Write-Host "Install: https://visualstudio.microsoft.com/downloads/ (Build Tools for Visual Studio)"
  return $null
}
$info = [pscustomobject]@{ arch = $arch; vsPath = $vsPath; vcvars = "$vsPath\VC\Auxiliary\Build\$batName" }
$info | ConvertTo-Json | Set-Content $saved
Write-Host "Tools located and saved to $saved"
return $info
