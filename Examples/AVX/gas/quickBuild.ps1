# Builds and runs the ARM64 GNU-syntax examples on Windows on Arm with clang (native ARM64).
#   .\quickBuild.ps1 03_dot_product_fmla      build and run one
#   .\quickBuild.ps1                          build and run all (07 says SVE is missing on most PCs)
# The examples are ASM_Template programs: asm_main + the template's 64_Bit_Windows_ARM library + its driver.c.
# Needs an ARM64 clang that can link Windows programs: the MSYS2 CLANGARM64 clang
# (pacman -S mingw-w64-clang-aarch64-clang, then put C:\msys64\clangarm64\bin on PATH), or LLVM for
# Windows on ARM64 with the Visual Studio C++ ARM64 build tools installed.
param([string]$name = "")
$all = "01_vector_add_neon","02_vector_add_pairs","03_dot_product_fmla","04_integer_sum","05_feature_detect","06_masked_tail","07_sve_predicate"
$list = if ($name) { @($name) } else { $all }

$clang = Get-Command clang.exe -ErrorAction SilentlyContinue
if (-not $clang) {
  Write-Host "clang.exe not found on PATH. See the comments at the top of this script."
  exit 1
}
$template = if ($env:ASM_TEMPLATE_HOME) { $env:ASM_TEMPLATE_HOME } else { (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path }
$lib = Join-Path $template "64_Bit_Windows_ARM"

Remove-Item ".\io.o" -ErrorAction SilentlyContinue
& $clang.Path -c "$lib\io_c_fallback.c" -o io.o
if ($LASTEXITCODE -ne 0) { Write-Host "Could not compile io_c_fallback.c"; exit 1 }
foreach ($n in $list) {
  Remove-Item ".\$n.exe", ".\$n.o" -ErrorAction SilentlyContinue
  & $clang.Path -g -c "$n.S" -o "$n.o"
  if ($LASTEXITCODE -ne 0) { Write-Host "Assemble failed: $n"; exit 1 }
  & $clang.Path "$n.o" io.o "$lib\driver.c" -o "$n.exe"
  if ($LASTEXITCODE -ne 0) { Write-Host "Link failed: $n"; exit 1 }
  Write-Host "=== $n"
  & ".\$n.exe"
}
