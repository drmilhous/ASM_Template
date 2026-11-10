# Builds and runs the Windows x64 C-library example.  Needs nasm and the MSVC x64 tools
# (run from an "x64 Native Tools" prompt, or point $TOOL_DIR at nasm).
$TOOL_DIR = "YY"
$env:Path += ";$TOOL_DIR"
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue
nasm -f win64 libc_calls.asm -o libc_calls.obj
if ($LASTEXITCODE -ne 0) { Write-Host "nasm failed"; exit 1 }
# cl links the C runtime and finds "main" for us; legacy_stdio_definitions provides printf
cl.exe /nologo libc_calls.obj /link legacy_stdio_definitions.lib
if ($LASTEXITCODE -ne 0) { Write-Host "link failed"; exit 1 }
.\libc_calls.exe
Write-Host "The last exit code is $LASTEXITCODE"
