# Builds and runs this project with the native ARM64 MSVC tools.
$projectName = "XX"
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.ARM64 -property installationPath
if (-not $vsPath) {
  Write-Host "ARM64 build tools not found. Install 'MSVC ARM64 build tools' in the Visual Studio Build Tools installer."
  exit 1
}
cmd.exe /c "call `"$vsPath\VC\Auxiliary\Build\vcvarsarm64.bat`" && set > %temp%\vcvars.txt"
Get-Content "$env:temp\vcvars.txt" | Foreach-Object {
  if ($_ -match "^(.*?)=(.*)$") { Set-Content "env:\$($matches[1])" $matches[2] }
}

armasm64.exe -nologo "$projectName.asm" -o "$projectName.obj"
if ($LASTEXITCODE -ne 0) { Write-Host "armasm64 failed on $projectName.asm"; exit 1 }
armasm64.exe -nologo io.asm -o io.obj
if ($LASTEXITCODE -ne 0) { Write-Host "armasm64 failed on io.asm"; exit 1 }

cl.exe /nologo /Zi driver.c "$projectName.obj" io.obj /Fe:"$projectName.exe"
if ($LASTEXITCODE -ne 0) { Write-Host "cl.exe failed"; exit 1 }

& ".\$projectName.exe"
Write-Host "The last exit code is $LASTEXITCODE"
