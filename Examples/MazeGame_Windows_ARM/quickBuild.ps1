# Builds and runs the maze game with the native ARM64 MSVC tools.
# Run it from this folder in a real console window (Windows Terminal is best).
# Optional: .\quickBuild.ps1 other_maze.txt
param([string]$maze = "maze.txt")
$projectName = "MazeGame"
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue

$findTools = Join-Path $PSScriptRoot "findTools.ps1"
if (-not (Test-Path $findTools)) { $findTools = Join-Path $PSScriptRoot "..\..\bin\findTools.ps1" }
$tools = & $findTools
if (-not $tools) { exit 1 }

cmd.exe /c "`"$($tools.vcvars)`" >nul && armasm64.exe -nologo maze_game.asm -o maze_game.obj && cl.exe /nologo /Zi driver.c maze_game.obj /Fe:$projectName.exe /link legacy_stdio_definitions.lib"
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }

& ".\$projectName.exe" $maze
Write-Host "The last exit code is $LASTEXITCODE"
