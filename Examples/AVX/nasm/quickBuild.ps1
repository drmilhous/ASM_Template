# Builds and runs one example (or all) on Windows x64 with NASM + Visual Studio x64 tools.
#   .\quickBuild.ps1 02_vector_add_avx        build and run one
#   .\quickBuild.ps1                          build and run all six
# Needs nasm.exe on your PATH. On Windows on ARM this builds an x64 program that runs under
# emulation, which does not support AVX: use an x64 PC (or Linux/macOS Intel) for these.
param([string]$name = "")
$all = "01_vector_add_sse","02_vector_add_avx","03_dot_product_fma","04_avx2_integer_sum","05_cpuid_detect","06_avx512_mask"
$list = if ($name) { @($name) } else { $all }

if (-not (Get-Command nasm.exe -ErrorAction SilentlyContinue)) {
  Write-Host "nasm.exe not found on PATH. Install NASM from https://www.nasm.us/ and reopen the console."
  exit 1
}
$findTools = Join-Path $PSScriptRoot "findTools.ps1"
if (-not (Test-Path $findTools)) { $findTools = Join-Path $PSScriptRoot "..\..\bin\findTools.ps1" }
$tools = & $findTools
if (-not $tools) { exit 1 }

foreach ($n in $list) {
  Remove-Item ".\$n.exe", ".\$n.obj" -ErrorAction SilentlyContinue
  # The build runs in a child cmd.exe, so your PowerShell PATH is never changed.
  # cl.exe only drives the linker here: it adds the C runtime start-up code that calls main.
  cmd.exe /c "`"$($tools.vcvars)`" >nul && nasm -f win64 $n.asm -o $n.obj && cl.exe /nologo $n.obj /Fe:$n.exe /link legacy_stdio_definitions.lib"
  if ($LASTEXITCODE -ne 0) { Write-Host "Build failed: $n"; exit 1 }
  Write-Host "=== $n"
  & ".\$n.exe"
}
