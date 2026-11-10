# Builds and runs the Windows ARM64 C-library example with the native ARM64 MSVC tools.
# Tool locations come from the saved info (findTools.ps1 creates it on the first run).
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue
$tools = & "$PSScriptRoot\..\..\bin\findTools.ps1"
if (-not $tools) { exit 1 }
# Object files from armasm64 carry no default-library hints, so name the C runtime libraries
# ourselves (static CRT). "main" is found through mainCRTStartup in libcmt.lib.
cmd.exe /c "`"$($tools.vcvars)`" >nul && armasm64.exe -nologo libc_calls.asm -o libc_calls.obj && link.exe /nologo /machine:ARM64 /subsystem:console /out:libc_calls.exe libc_calls.obj libcmt.lib libvcruntime.lib libucrt.lib kernel32.lib legacy_stdio_definitions.lib"
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }
.\libc_calls.exe
Write-Host "The last exit code is $LASTEXITCODE"
