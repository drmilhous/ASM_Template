# Builds and runs this project with the native ARM64 MSVC tools.
# The build runs inside a child cmd.exe, so your PowerShell PATH is never changed.
$projectName = "XX"
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.ARM64 -property installationPath
if (-not $vsPath) {
  Write-Host "ARM64 build tools not found. Install 'MSVC ARM64 build tools' in the Visual Studio Build Tools installer."
  exit 1
}
$vcvars = "$vsPath\VC\Auxiliary\Build\vcvarsarm64.bat"

cmd.exe /c "`"$vcvars`" >nul && armasm64.exe -nologo $projectName.asm -o $projectName.obj && cl.exe /nologo /Zi driver.c io.c $projectName.obj /Fe:$projectName.exe /link legacy_stdio_definitions.lib"
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }

& ".\$projectName.exe"
Write-Host "The last exit code is $LASTEXITCODE"
