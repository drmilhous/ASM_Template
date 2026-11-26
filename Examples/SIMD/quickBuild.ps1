# Run in the VS developer shell for the selected target. ARM64 also needs LLVM clang.
param(
    [ValidateSet('x64','arm64')][string]$Arch = $(if ($env:VSCMD_ARG_TGT_ARCH -eq 'arm64') { 'arm64' } else { 'x64' }),
    [switch]$Test
)
$ErrorActionPreference = 'Stop'
$buildArgs = @((Join-Path $PSScriptRoot 'build.py'), '--arch', $Arch)
if ($Test) { $buildArgs += '--test' }
python @buildArgs
exit $LASTEXITCODE
