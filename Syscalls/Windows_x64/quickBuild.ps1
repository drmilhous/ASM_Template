# Builds and runs the Windows x64 syscall examples.  Needs nasm and the MSVC x64
# tools (run from an "x64 Native Tools" prompt, or point $TOOL_DIR at nasm).
$TOOL_DIR = "YY"
$env:Path += ";$TOOL_DIR"
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue

foreach ($name in "syscalls_api", "syscalls_raw") {
    nasm -f win64 "$name.asm" -o "$name.obj"
    if ($LASTEXITCODE -ne 0) { Write-Host "nasm failed on $name.asm"; exit 1 }
    link.exe /nologo /subsystem:console /entry:start /out:"$name.exe" "$name.obj" kernel32.lib
    if ($LASTEXITCODE -ne 0) { Write-Host "link failed on $name"; exit 1 }
    Write-Host "---- $name.exe ----"
    & ".\$name.exe"
    Write-Host "The last exit code is $LASTEXITCODE"
}
