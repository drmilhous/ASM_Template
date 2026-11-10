# Usage: WindowsArmProject.ps1 <project_name>
# Creates a native Windows ARM64 project in the project folder.
$asmHome = if ($env:ASM_TEMPLATE_HOME) { $env:ASM_TEMPLATE_HOME } else { Split-Path -Parent $PSScriptRoot }
$projects = if ($env:ASM_PROJECTS) { $env:ASM_PROJECTS } else { "$env:USERPROFILE\Projects" }
$baseDir = "$asmHome\64_Bit_Windows_ARM"
$projectName = $args[0]
if (-not $projectName) { Write-Host "Please provide a project name"; exit 1 }
$projectDir = "$projects\$projectName"
if (Test-Path $projectDir) { Write-Host "The project already exists"; exit 1 }
New-Item -ItemType Directory -Force -Path $projectDir | Out-Null
Copy-Item "$baseDir\arm64.asm" "$projectDir\$projectName.asm"
Copy-Item "$baseDir\io.asm", "$baseDir\driver.c" $projectDir
(Get-Content "$baseDir\quickBuild.ps1").Replace('XX', $projectName) | Set-Content "$projectDir\quickBuild.ps1"
Write-Host "Project $projectDir created. Run .\quickBuild.ps1 from that folder."
