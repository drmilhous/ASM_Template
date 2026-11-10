# Usage: setup.ps1 [project_folder]
# Run from the folder that holds ASM_Template (or from ASM_Template itself).
$cur = (Get-Location).Path
if (Test-Path "$cur\ASM_Template\bin") { $asmHome = "$cur\ASM_Template" }
elseif (Test-Path "$cur\bin\asm_env.sh") { $asmHome = $cur }
else { Write-Host "Run setup.ps1 from the ASM_Template folder (or its parent)."; exit 1 }
$proj = if ($args[0]) { $args[0] } else { "$env:USERPROFILE\Projects" }
New-Item -ItemType Directory -Force -Path $proj | Out-Null
$proj = (Resolve-Path $proj).Path
[Environment]::SetEnvironmentVariable("ASM_TEMPLATE_HOME", $asmHome, "User")
[Environment]::SetEnvironmentVariable("ASM_PROJECTS", $proj, "User")
Write-Host "Install folder : $asmHome"
Write-Host "Project folder : $proj"
Write-Host "Open a new terminal for the variables to take effect."
