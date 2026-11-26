#!/usr/bin/env python3
"""Build native SIMD examples; optionally run the result-checking C drivers.
Windows: run in a Visual Studio developer shell for the chosen target.
"""
import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
PROGRAMS = ('01_vector_add', '02_dot_product', '03_integer_sum')

def run(args, cwd):
    print(' '.join(str(a) for a in args), flush=True)
    subprocess.run([str(a) for a in args], cwd=cwd, check=True)

def main():
    host = platform.machine().lower()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--arch', choices=('x64', 'arm64'), default='arm64' if host in ('arm64', 'aarch64') else 'x64')
    parser.add_argument('--test', action='store_true', help='Run tests; unsupported x86 extensions are reported as SKIP')
    parser.add_argument('--example', choices=PROGRAMS, help='Build only one example')
    args = parser.parse_args()
    system = platform.system()
    if system not in ('Darwin', 'Linux', 'Windows'):
        parser.error('Supported hosts: macOS, Linux, Windows')
    if system == 'Linux' and ((args.arch == 'arm64') != (host in ('arm64', 'aarch64'))):
        parser.error('Linux builds use the native compiler. Build on a matching Linux host/VM.')
    windows = system == 'Windows'
    cc = 'cl' if windows else os.environ.get('CC', 'cc')
    needed = [cc, 'nasm'] if args.arch == 'x64' else [cc] + (['clang'] if windows else [])
    for tool in needed:
        if not shutil.which(tool):
            parser.error(f'{tool} not on PATH; see README prerequisites')
    if windows:
        target = os.environ.get('VSCMD_ARG_TGT_ARCH', '').lower()
        if target != args.arch:
            parser.error(f'Open a Visual Studio {args.arch} target developer shell (current target: {target or "unknown"})')
    out = ROOT / 'build' / f'{system.lower()}-{args.arch}'
    out.mkdir(parents=True, exist_ok=True)
    target_flags = ['-arch', 'arm64' if args.arch == 'arm64' else 'x86_64'] if system == 'Darwin' else []
    fmt = {'Darwin': 'macho64', 'Linux': 'elf64', 'Windows': 'win64'}[system]
    asm_debug = {'Darwin': [], 'Linux': ['-g', '-F', 'dwarf'], 'Windows': ['-g', '-F', 'cv8']}[system]
    objects = []
    if args.arch == 'x64':
        feature_obj = out / 'features.o'
        run(['nasm', '-f', fmt, *asm_debug, '-I', str(ROOT / 'nasm') + os.sep, ROOT / 'nasm/features.asm', '-o', feature_obj], out)
        objects.append(feature_obj)
    passed = skipped = 0
    for number, name in enumerate(PROGRAMS, 1):
        if args.example and args.example != name:
            continue
        obj = out / f'{name}.o'
        exe = out / (name + ('.exe' if windows else ''))
        if args.arch == 'x64':
            run(['nasm', '-f', fmt, *asm_debug, '-I', str(ROOT / 'nasm') + os.sep, ROOT / 'nasm' / (name + '.asm'), '-o', obj], out)
        else:
            arm_cc = 'clang' if windows else cc
            flags = ['--target=aarch64-pc-windows-msvc', '-g', '-gcodeview'] if windows else [*target_flags, '-g']
            run([arm_cc, *flags, '-c', ROOT / 'neon' / (name + '.S'), '-o', obj], out)
        if windows:
            definitions = [f'/DCASE={number}'] + (['/DSIMD_X64'] if args.arch == 'x64' else [])
            run([cc, '/nologo', '/std:c11', '/Od', '/Zi', *definitions, ROOT / 'driver.c', obj, *objects, f'/Fe:{exe}', '/link', '/DEBUG'], out)
        else:
            definitions = [f'-DCASE={number}'] + (['-DSIMD_X64'] if args.arch == 'x64' else [])
            # Keep C objects: macOS debug maps reference them for source/locals.
            driver_obj = out / f'{name}_driver.o'
            run([cc, *target_flags, '-std=c11', '-g', '-O0', '-ffp-contract=off', *definitions, '-c', ROOT / 'driver.c', '-o', driver_obj], out)
            run([cc, *target_flags, '-g', driver_obj, obj, *objects, '-o', exe], out)
            if system == 'Darwin':
                run(['dsymutil', exe], out)
        if args.test:
            result = subprocess.run([str(exe)], cwd=out)
            if result.returncode == 77:
                skipped += 1
            elif result.returncode:
                return result.returncode
            else:
                passed += 1
    print(f'Output: {out}')
    if args.test:
        print(f'Test summary: {passed} passed, {skipped} skipped')
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (subprocess.CalledProcessError, OSError) as error:
        print(f'Build/run failed: {error}', file=sys.stderr)
        sys.exit(1)
