# Builds and runs the GNU as AVX examples on Windows x64 with MinGW-w64 gcc (or clang).
#   .\quickBuild.ps1 02_vector_add_avx        build and run one
#   .\quickBuild.ps1                          build and run all six
# Visual Studio has no GNU as, so this needs gcc: install MSYS2 (https://www.msys2.org/), then in the
# "MSYS2 MINGW64" shell run:  pacman -S mingw-w64-x86_64-gcc make   and add C:\msys64\mingw64\bin to PATH.
# On Windows on ARM this would build an x64 program that runs under emulation, which does not support
# AVX: use an x64 PC (or Linux/macOS Intel) for these.
param([string]$name = "")
$all = "01_vector_add_sse","02_vector_add_avx","03_dot_product_fma","04_avx2_integer_sum","05_cpuid_detect","06_avx512_mask"
$list = if ($name) { @($name) } else { $all }

$cc = Get-Command gcc.exe -ErrorAction SilentlyContinue
if (-not $cc) { $cc = Get-Command clang.exe -ErrorAction SilentlyContinue }
if (-not $cc) {
  Write-Host "gcc.exe (MinGW-w64) not found on PATH. See the comments at the top of this script."
  exit 1
}
foreach ($n in $list) {
  Remove-Item ".\$n.exe", ".\$n.o" -ErrorAction SilentlyContinue
  & $cc.Path -g -c "$n.S" -o "$n.o"
  if ($LASTEXITCODE -ne 0) { Write-Host "Assemble failed: $n"; exit 1 }
  & $cc.Path "$n.o" -o "$n.exe"
  if ($LASTEXITCODE -ne 0) { Write-Host "Link failed: $n"; exit 1 }
  Write-Host "=== $n"
  & ".\$n.exe"
}
