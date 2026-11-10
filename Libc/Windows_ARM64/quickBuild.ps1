# Builds and runs the Windows ARM64 C-library example with the native ARM64 MSVC tools.
# Tool locations come from the saved info (findTools.ps1 creates it on the first run).
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue
$tools = & "$PSScriptRoot\..\..\bin\findTools.ps1"
if (-not $tools) { exit 1 }
# cl links the C runtime and finds "main" for us; legacy_stdio_definitions provides printf
cmd.exe /c "`"$($tools.vcvars)`" >nul && armasm64.exe -nologo libc_calls.asm -o libc_calls.obj && cl.exe /nologo libc_calls.obj /link legacy_stdio_definitions.lib"
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }
.\libc_calls.exe
Write-Host "The last exit code is $LASTEXITCODE"
