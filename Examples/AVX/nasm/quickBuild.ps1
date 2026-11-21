# Builds and runs one example (or all) on Windows x64 with NASM + Visual Studio x64 tools.
#   .\quickBuild.ps1 02_vector_add_avx        build and run one
#   .\quickBuild.ps1                          build and run all six
# The examples are ASM_Template programs: asm_main + the template's io.asm library + its driver.c.
# Needs nasm.exe on your PATH. On Windows on ARM this builds an x64 program that runs under
# emulation, which does not support AVX: use an x64 PC (or Linux/macOS Intel) for these.
param([string]$name = "")
$all = "01_vector_add_sse","02_vector_add_avx","03_dot_product_fma","04_avx2_integer_sum","05_cpuid_detect","06_avx512_mask"
$list = if ($name) { @($name) } else { $all }

if (-not (Get-Command nasm.exe -ErrorAction SilentlyContinue)) {
  Write-Host "nasm.exe not found on PATH. Install NASM from https://www.nasm.us/ and reopen the console."
  exit 1
}
$template = if ($env:ASM_TEMPLATE_HOME) { $env:ASM_TEMPLATE_HOME } else { (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path }
$lib = Join-Path $template "64_Bit_Windows"
$findTools = Join-Path $PSScriptRoot "findTools.ps1"
if (-not (Test-Path $findTools)) { $findTools = Join-Path $template "bin\findTools.ps1" }
$tools = & $findTools
if (-not $tools) { exit 1 }

foreach ($n in $list) {
  Remove-Item ".\$n.exe", ".\$n.obj", ".\io.obj" -ErrorAction SilentlyContinue
  # The build runs in a child cmd.exe, so your PowerShell PATH is never changed.
  cmd.exe /c "`"$($tools.vcvars)`" >nul && nasm -f win64 `"$lib\io.asm`" -o io.obj && nasm -f win64 -I`"$lib\`" -I. $n.asm -o $n.obj && cl.exe /nologo `"$lib\driver.c`" $n.obj io.obj /Fe:$n.exe /link legacy_stdio_definitions.lib"
  if ($LASTEXITCODE -ne 0) { Write-Host "Build failed: $n"; exit 1 }
  Write-Host "=== $n"
  & ".\$n.exe"
}
