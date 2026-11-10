# Builds and runs both Windows ARM64 syscall examples with the native ARM64 MSVC tools.
# Tool locations come from the saved info (findTools.ps1 creates it on the first run).
# The build runs inside a child cmd.exe, so your PowerShell PATH is never changed.
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue

$tools = & "$PSScriptRoot\..\..\bin\findTools.ps1"
if (-not $tools) { exit 1 }

foreach ($name in "syscalls_api", "syscalls_raw") {
    cmd.exe /c "`"$($tools.vcvars)`" >nul && armasm64.exe -nologo $name.asm -o $name.obj && link.exe /nologo /machine:ARM64 /subsystem:console /entry:start /out:$name.exe $name.obj kernel32.lib"
    if ($LASTEXITCODE -ne 0) { Write-Host "Build failed for $name"; exit 1 }
    Write-Host "---- $name.exe ----"
    & ".\$name.exe"
    Write-Host "The last exit code is $LASTEXITCODE"
}
