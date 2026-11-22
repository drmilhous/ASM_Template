[CmdletBinding()]
param(
    [string]$ProjectDirectory = '.',
    [string]$Source,
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    [switch]$Run,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
& "$PSScriptRoot\Build-Windows.ps1" -Architecture x64 @PSBoundParameters
exit $LASTEXITCODE
