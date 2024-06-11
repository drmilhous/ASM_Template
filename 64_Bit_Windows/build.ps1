$projectName = "XX"
Remove-Item .\*.exe
Remove-Item .\*.obj
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

$vcvarspath = &$vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
Write-Output "vc tools located at: $vcvarspath"

cmd.exe /c "call `"$vcvarspath\VC\Auxiliary\Build\vcvars64.bat`" && set > %temp%\vcvars.txt"

Get-Content "$env:temp\vcvars.txt" | Foreach-Object {
  if ($_ -match "^(.*?)=(.*)$") {
    Set-Content "env:\$($matches[1])" $matches[2]
  }
}
nasm -f win64 "$projectName.asm"
if ($LASTEXITCODE -gt 0)
{
  Write-Host "Nasm failed to assemble $projectName.asm"
  exit
}
cl.exe .\$projectName.obj .\driver.c /link /out:$projectName.exe
if ($LASTEXITCODE -gt 0)
{
  Write-Host "cl.exe failed to compile $projectName.obj and driver.c"
  exit
}
Invoke-Expression -Command ".\$projectName.exe"
$LASTEXITCODE