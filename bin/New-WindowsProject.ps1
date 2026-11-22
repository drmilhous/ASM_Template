[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [ValidateSet('x64', 'arm64')]
    [string]$Architecture,
    [string]$ProjectsDirectory
)

$ErrorActionPreference = 'Stop'

try {
    if ($Name -match '[<>:"/\\|?*%\x00-\x1f]' -or $Name -match '[. ]$' -or
        $Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)' -or
        $Name -in @('io', 'driver') -or [string]::IsNullOrWhiteSpace($Name)) {
        throw 'Choose a valid Windows folder name other than io or driver, without percent signs or trailing dots/spaces.'
    }
    $asmHome = if ($env:ASM_TEMPLATE_HOME) { $env:ASM_TEMPLATE_HOME } else { Split-Path -Parent $PSScriptRoot }
    $asmHome = (Resolve-Path -LiteralPath $asmHome).ProviderPath
    if (-not $ProjectsDirectory) {
        $ProjectsDirectory = if ($env:ASM_PROJECTS) { $env:ASM_PROJECTS } else {
            Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Projects'
        }
    }
    $Architecture = $Architecture.ToLowerInvariant()
    $templateFolder = if ($Architecture -eq 'x64') { '64_Bit_Windows' } else { '64_Bit_Windows_ARM' }
    $templateSource = if ($Architecture -eq 'x64') { '64bit.asm' } else { 'arm64.asm' }
    $templatePath = Join-Path $asmHome $templateFolder
    $builder = Join-Path $asmHome "bin/Build-Windows-$Architecture.ps1"
    $sourceFiles = @('driver.c', 'io.asm')
    if ($Architecture -eq 'x64') {
        $sourceFiles += 'io.inc'
    }
    foreach ($requiredPath in @($builder, (Join-Path $asmHome 'bin/Build-Windows.ps1'), (Join-Path $templatePath $templateSource))) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Required template or builder not found: $requiredPath"
        }
    }
    foreach ($sourceFile in $sourceFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $templatePath $sourceFile) -PathType Leaf)) {
            throw "Required template source not found: $sourceFile"
        }
    }
    $projectPath = Join-Path $ProjectsDirectory $Name
    if (Test-Path -LiteralPath $projectPath) {
        throw "Project already exists; nothing was changed: $projectPath"
    }
    New-Item -ItemType Directory -Path $ProjectsDirectory -Force | Out-Null
    $projectPath = Join-Path (Resolve-Path -LiteralPath $ProjectsDirectory).ProviderPath $Name
    New-Item -ItemType Directory -Path $projectPath | Out-Null
    Copy-Item -LiteralPath (Join-Path $templatePath $templateSource) -Destination (Join-Path $projectPath "$Name.asm")
    foreach ($sourceFile in $sourceFiles) {
        Copy-Item -LiteralPath (Join-Path $templatePath $sourceFile) -Destination $projectPath
    }
    [ordered]@{
        architecture = $Architecture
        source = "$Name.asm"
        templateHome = $asmHome
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectPath '.asm-template.json') -Encoding UTF8

    $buildLauncher = @'
[CmdletBinding()]
param(
    [string]$Source,
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    [switch]$Run,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
try {
    $project = Get-Content -LiteralPath (Join-Path $PSScriptRoot '.asm-template.json') -Raw | ConvertFrom-Json
    if ($project.architecture -notin @('x64', 'arm64')) {
        throw 'Invalid architecture in .asm-template.json.'
    }
    $templateHome = if ($env:ASM_TEMPLATE_HOME) { $env:ASM_TEMPLATE_HOME } else { $project.templateHome }
    $builder = Join-Path $templateHome "bin/Build-Windows-$($project.architecture).ps1"
    if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) {
        throw 'Linked builder not found. Set ASM_TEMPLATE_HOME to the ASM_Template installation folder, or update templateHome in .asm-template.json.'
    }
    if (-not $PSBoundParameters.ContainsKey('Source')) {
        $PSBoundParameters['Source'] = $project.source
    }
    & $builder -ProjectDirectory $PSScriptRoot @PSBoundParameters
    exit $LASTEXITCODE
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
'@
    $runLauncher = @'
[CmdletBinding()]
param(
    [string]$Source,
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug'
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'build.ps1') -Run @PSBoundParameters
exit $LASTEXITCODE
'@
    Set-Content -LiteralPath (Join-Path $projectPath 'build.ps1') -Value $buildLauncher -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $projectPath 'run.ps1') -Value $runLauncher -Encoding UTF8
    Write-Host "Created $Architecture project: $projectPath"
    Write-Host 'Inside that directory, use .\build.ps1 to build or .\run.ps1 to build and run.'
    Write-Host "The local launchers use the shared builder at $builder"
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
