# Builds and runs the Intel x64 maze game on Windows (NASM + Visual Studio x64 tools).
# Needs nasm.exe on your PATH and a real console window (Windows Terminal is best).
# Optional: .\quickBuild.ps1 other_maze.txt
# On Windows on ARM this needs the x64 tools and would run under emulation; use
# ..\MazeGame_Windows_ARM for a native build instead.
param([string]$maze = "maze.txt")
$projectName = "MazeGame"
Remove-Item .\*.exe, .\*.obj -ErrorAction SilentlyContinue

if (-not (Get-Command nasm.exe -ErrorAction SilentlyContinue)) {
  Write-Host "nasm.exe not found on PATH. Install NASM from https://www.nasm.us/ and reopen the console."
  exit 1
}
$findTools = Join-Path $PSScriptRoot "findTools.ps1"
if (-not (Test-Path $findTools)) { $findTools = Join-Path $PSScriptRoot "..\..\bin\findTools.ps1" }
$tools = & $findTools
if (-not $tools) { exit 1 }

# The build runs in a child cmd.exe, so your PowerShell PATH is never changed.
cmd.exe /c "`"$($tools.vcvars)`" >nul && nasm -f win64 maze_game.asm -o maze_game.obj && cl.exe /nologo /Zi driver.c maze_game.obj /Fe:$projectName.exe /link legacy_stdio_definitions.lib"
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }

& ".\$projectName.exe" $maze
Write-Host "The last exit code is $LASTEXITCODE"
