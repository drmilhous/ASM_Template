$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

$vcvarspath = &$vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
Write-Output "vc tools located at: $vcvarspath"

cmd.exe /c "call `"$vcvarspath\VC\Auxiliary\Build\vcvars64.bat`" && set > %temp%\vcvars.txt"

Get-Content "$env:temp\vcvars.txt" | Foreach-Object {
  if ($_ -match "^(.*?)=(.*)$") {
    Set-Content "env:\$($matches[1])" $matches[2]
  }
}
$CL_LOC = (Get-Command cl.exe).Path 
Write-Output "cl.exe located at: $CL_LOC"
$CL_LOC = (Get-Command link.exe).Path 
Write-Output "link.exe located at: $CL_LOC"
$CL_LOC = (Get-Command ml64.exe).Path 
Write-Output "ml64.exe located at: $CL_LOC"
