[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('x64', 'arm64')]
    [string]$Architecture,
    [string]$ProjectDirectory = '.',
    [string]$Source,
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    [switch]$Run,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$batchPath = $null

function Quote-BatchPath([string]$Path) {
    if ($Path -match '[%"\r\n]') {
        throw 'Build paths cannot contain percent signs, quotes, or newlines.'
    }
    return '"' + $Path + '"'
}

try {
    if ($env:OS -ne 'Windows_NT') {
        throw 'This builder requires Windows and Visual Studio C++ Build Tools.'
    }
    if ($Clean -and $Run) {
        throw 'Use -Clean separately from -Run.'
    }

    $projectPath = (Resolve-Path -LiteralPath $ProjectDirectory).ProviderPath
    if (-not (Test-Path -LiteralPath $projectPath -PathType Container)) {
        throw 'ProjectDirectory must be a directory.'
    }
    $outputPath = Join-Path $projectPath "build\$Architecture\$Configuration"
    if ($Clean) {
        if (Test-Path -LiteralPath $outputPath) {
            Remove-Item -LiteralPath $outputPath -Recurse -Force
        }
        Write-Host "Cleaned $outputPath"
        exit 0
    }

    if (-not $Source) {
        $candidates = @(Get-ChildItem -LiteralPath $projectPath -Filter '*.asm' -File |
            Where-Object { $_.Name -ne 'io.asm' })
        if ($candidates.Count -ne 1) {
            throw 'Specify -Source <file.asm> when the project does not contain exactly one program assembly file.'
        }
        $Source = $candidates[0].Name
    }
    $sourcePath = if ([IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $projectPath $Source }
    $sourcePath = (Resolve-Path -LiteralPath $sourcePath).ProviderPath
    if ([IO.Path]::GetExtension($sourcePath) -ne '.asm') {
        throw 'Source must be an .asm file.'
    }
    $projectName = [IO.Path]::GetFileNameWithoutExtension($sourcePath)
    if ($projectName -in @('io', 'driver')) {
        throw 'The program source cannot be named io.asm or driver.asm.'
    }
    $driverPath = Join-Path $projectPath 'driver.c'
    $ioPath = Join-Path $projectPath 'io.asm'
    foreach ($requiredPath in @($sourcePath, $driverPath, $ioPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Required source file not found: $requiredPath"
        }
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) {
        throw 'Install Visual Studio Build Tools with the Desktop development with C++ workload.'
    }
    $components = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64')
    if ($Architecture -eq 'arm64') {
        $components += 'Microsoft.VisualStudio.Component.VC.Tools.ARM64'
    }
    $vsPath = & $vswhere -latest -products '*' -requires $components -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $vsPath) {
        throw "Visual Studio tools not found. Required components: $($components -join ', ')"
    }
    $vcvarsPath = Join-Path $vsPath 'VC\Auxiliary\Build\vcvarsall.bat'
    if (-not (Test-Path -LiteralPath $vcvarsPath)) {
        throw "Visual Studio environment script not found: $vcvarsPath"
    }
    $vcvarsArchitecture = if ($Architecture -eq 'arm64') { 'amd64_arm64' } else { 'amd64' }
    $programObject = Join-Path $outputPath "$projectName.obj"
    $ioObject = Join-Path $outputPath 'io.obj'
    $driverObject = Join-Path $outputPath 'driver.obj'
    $executable = Join-Path $outputPath "$projectName.exe"
    $pdb = Join-Path $outputPath "$projectName.pdb"

    $commands = @(
        '@echo off',
        'setlocal DisableDelayedExpansion',
        'chcp 65001 >nul',
        "call $(Quote-BatchPath $vcvarsPath) $vcvarsArchitecture >nul",
        'if errorlevel 1 exit /b 1',
        "pushd $(Quote-BatchPath $projectPath)",
        'if errorlevel 1 exit /b 1'
    )
    $assemblyPairs = @(
        @{ Source = $sourcePath; Object = $programObject },
        @{ Source = $ioPath; Object = $ioObject }
    )
    if ($Architecture -eq 'x64') {
        $commands += @('where nasm.exe >nul 2>nul', 'if errorlevel 1 (echo NASM is missing. Add nasm.exe to PATH. & exit /b 1)')
        $assemblyFlags = if ($Configuration -eq 'Debug') { '-g -F cv8' } else { '' }
        foreach ($pair in $assemblyPairs) {
            $commands += "nasm.exe -f win64 $assemblyFlags $(Quote-BatchPath $pair.Source) -o $(Quote-BatchPath $pair.Object)"
            $commands += 'if errorlevel 1 exit /b 1'
        }
    } else {
        foreach ($pair in $assemblyPairs) {
            $commands += "armasm64.exe -nologo $(Quote-BatchPath $pair.Source) -o $(Quote-BatchPath $pair.Object)"
            $commands += 'if errorlevel 1 exit /b 1'
        }
    }
    $compilerFlags = if ($Configuration -eq 'Debug') { '/Od /Z7' } else { '/O2' }
    $linkerFlags = if ($Configuration -eq 'Debug') { "/DEBUG /PDB:$(Quote-BatchPath $pdb)" } else { '' }
    $commands += @(
        "cl.exe /nologo $compilerFlags /c $(Quote-BatchPath $driverPath) /Fo$(Quote-BatchPath $driverObject)",
        'if errorlevel 1 exit /b 1',
        "cl.exe /nologo $(Quote-BatchPath $driverObject) $(Quote-BatchPath $programObject) $(Quote-BatchPath $ioObject) /Fe$(Quote-BatchPath $executable) /link /SUBSYSTEM:CONSOLE /MACHINE:$Architecture /INCREMENTAL:NO $linkerFlags legacy_stdio_definitions.lib",
        'if errorlevel 1 exit /b 1',
        'popd',
        'exit /b 0'
    )

    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    $batchPath = Join-Path $outputPath ('.build-' + [guid]::NewGuid().ToString('N') + '.cmd')
    [IO.File]::WriteAllText($batchPath, ($commands -join "`r`n") + "`r`n", [Text.UTF8Encoding]::new($false))
    Write-Host "Building $projectName ($Architecture, $Configuration)"
    & $env:ComSpec /d /s /c "`"$(Quote-BatchPath $batchPath)`""
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed. The program was not run. Output directory: $outputPath"
    }
    Write-Host "Built $executable"
    if ($Run) {
        Push-Location -LiteralPath $projectPath
        try {
            & $executable
            $programExitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        Write-Host "Program exit code: $programExitCode"
        exit $programExitCode
    }
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally {
    if ($batchPath -and (Test-Path -LiteralPath $batchPath)) {
        Remove-Item -LiteralPath $batchPath -Force -ErrorAction SilentlyContinue
    }
}
