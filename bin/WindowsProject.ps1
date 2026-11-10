
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vcvarspath = &$vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
Write-Output "vc tools located at: $vcvarspath"
cmd.exe /c "call `"$vcvarspath\VC\Auxiliary\Build\vcvars64.bat`" && set > %temp%\vcvars.txt"
Get-Content "$env:temp\vcvars.txt" | Foreach-Object {
  if ($_ -match "^(.*?)=(.*)$") {
    Set-Content "env:\$($matches[1])" $matches[2]
  }
}
$CL_LOC = (Get-Command cl.exe).Path.Replace("cl.exe","") 
Write-Host "Building $projectName"
# Set the path to the project directory
# Locations: ASM_TEMPLATE_HOME (install folder) and ASM_PROJECTS (project folder).
# Set by setup.ps1 or the environment; defaults below.
$asmHome = if ($env:ASM_TEMPLATE_HOME) { $env:ASM_TEMPLATE_HOME } else { Split-Path -Parent $PSScriptRoot }
$projects = if ($env:ASM_PROJECTS) { $env:ASM_PROJECTS } else { "$env:USERPROFILE\Projects" }
$baseDir = "$asmHome\64_Bit_Windows"
$projectName = $args[0]
$projectDir = "$projects\$projectName"

Write-Host $projectName
# check if the project directory is empty
if (-not $projectName) {
    Write-Host "Please provide a project name"
    exit
}
#check if the project directory already exists
if (Test-Path -Path "$projectDir") {
    Write-Host "The project already exists"
    exit
}
# New-Item -ItemType Directory -Force -Path "$projectDir"
Write-Host "Creating project directory $projectDir"
Copy-Item -Path "$baseDir" -Destination "$projectDir" -Recurse
Rename-Item -Path "$projectDir\64bit.asm" -NewName "$projectName.asm"
Write-Host "Project  $projectDir created successfully!"
(Get-Content $baseDir\quickBuild.ps1 ).Replace('XX',$projectName).Replace("YY",$CL_LOC) | Set-Content  "$projectDir\quickBuild.ps1"

# (New-Object -ComObject WScript.Shell).RegRead("HKLM\SOFTWARE\Microsoft\MSBuild\ToolsVersions\4.0\MSBuildToolsPath")
# (New-Object -ComObject WScript.Shell).RegRead("HKEY_CURRENT_USER\SOFTWARE\Microsoft\VisualStudio\SxS\VC7")

# Get-Item -Path Registry::HKLM\SOFTWARE\Microsoft\MSBuild\ToolsVersions\4.0 /v MSBuildToolsPath |
#     Select-Object -ExpandProperty Property

# #copy files in base directory to the project directory
# Copy-Item -Path "$baseDir\64_Bit_Windows\" -Destination "$projects\$projectDir" -Recurse
# Write-Host "Project  "$projects\$projectDir" created successfully!"


# C:\Program Files(x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.40.33807\bin\Hostx64\x64\
# # Change to the project directory
# #Set-Location -Path $projectDir -ErrorAction Stop

# C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -noe -c "&{Import-Module 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll'; Enter-VsDevShell 14bbfab9}"

# Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"; Enter-VsDevShell 14bbfab9
# Write the script content to the file
#@"
# Add your PowerShell code here
#Write-Host "Hello, PowerShell!"

# End of script
#"@ | Set-Content -Path $scriptFile -ErrorAction Stop

# Display a success message
#Write-Host "PowerShell script created successfully!"