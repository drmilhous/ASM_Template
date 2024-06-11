$TOOL_DIR="YY"
$projectName = "XX"
Remove-Item .\*.exe
Remove-Item .\*.obj
$env:Path += ';$TOOL_DIR' 

nasm -f win64 "$projectName.asm"
if ($LASTEXITCODE -gt 0)
{
  Write-Host "Nasm failed to assemble $projectName.asm"
  exit
}
cl.exe /Zi .\$projectName.obj .\driver.c

link.exe .\driver.obj .\$projectName.obj /subsystem:console /out:$projectName.exe kernel32.lib legacy_stdio_definitions.lib 
#link .\driver.obj .\$projectName.obj /subsystem:console /out:$projectName.exe kernel32.lib legacy_stdio_definitions.lib msvcrt.lib

if ($LASTEXITCODE -gt 0)
{
  Write-Host "cl.exe failed to compile $projectName.obj and driver.c"
  exit
}
Invoke-Expression -Command ".\$projectName.exe"
Write-Host "The last exit code is $LASTEXITCODE"