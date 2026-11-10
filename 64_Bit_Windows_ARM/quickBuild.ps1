# Builds and runs this project with the native ARM64 MSVC tools.
# Tool locations come from the saved info (findTools.ps1 creates it on the first run).
# The build runs inside a child cmd.exe, so your PowerShell PATH is never changed.
$projectName = "XX"
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue

$tools = & "$PSScriptRoot\findTools.ps1"
if (-not $tools) { exit 1 }

cmd.exe /c "`"$($tools.vcvars)`" >nul && armasm64.exe -nologo $projectName.asm -o $projectName.obj && armasm64.exe -nologo io.asm -o io.obj && cl.exe /nologo /Zi driver.c $projectName.obj io.obj /Fe:$projectName.exe /link legacy_stdio_definitions.lib"
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }

& ".\$projectName.exe"
Write-Host "The last exit code is $LASTEXITCODE"
