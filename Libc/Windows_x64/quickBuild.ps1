# Builds and runs the Windows x64 C-library example.  Needs nasm and the MSVC x64 tools
# (run from an "x64 Native Tools" prompt, or point $TOOL_DIR at nasm).
$TOOL_DIR = "YY"
$env:Path += ";$TOOL_DIR"
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue
nasm -f win64 libc_calls.asm -o libc_calls.obj
if ($LASTEXITCODE -ne 0) { Write-Host "nasm failed"; exit 1 }
# An object file from nasm carries no default-library hints, so name the C runtime libraries
# ourselves (static CRT). "main" is found through mainCRTStartup in libcmt.lib.
link.exe /nologo /machine:X64 /subsystem:console /out:libc_calls.exe libc_calls.obj libcmt.lib libvcruntime.lib libucrt.lib kernel32.lib legacy_stdio_definitions.lib
if ($LASTEXITCODE -ne 0) { Write-Host "link failed"; exit 1 }
.\libc_calls.exe
Write-Host "The last exit code is $LASTEXITCODE"
