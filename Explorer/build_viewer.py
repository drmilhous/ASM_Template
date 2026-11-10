#!/usr/bin/env python3
"""Regenerates index.html (the searchable syscall / C-library explorer) from the example sources.
Usage: python3 Explorer/build_viewer.py      (run from anywhere; writes next to this script)"""
import json, pathlib
here = pathlib.Path(__file__).parent
root = here.parent

# (folder, OS, architecture label, source files)
PLATFORMS = [
    ("Linux_x64",     "Linux",   "x86-64",        ["syscalls.asm"]),
    ("Linux_x86_32",  "Linux",   "x86 (32-bit)",  ["syscalls.asm"]),
    ("Linux_ARM64",   "Linux",   "ARM64",         ["syscalls.s"]),
    ("Linux_ARM32",   "Linux",   "ARM (32-bit)",  ["syscalls.s"]),
    ("macOS_ARM64",   "macOS",   "ARM64",         ["syscalls.s"]),
    ("macOS_x64",     "macOS",   "x86-64",        ["syscalls.asm"]),
    ("Windows_x64",   "Windows", "x86-64",        ["syscalls_api.asm", "syscalls_raw.asm"]),
    ("Windows_ARM64", "Windows", "ARM64",         ["syscalls_api.asm", "syscalls_raw.asm"]),
]
# Quick-reference table: instruction / number register / args / error style
INFO = {
 "Linux_x64":     ("syscall", "rax", "rdi rsi rdx r10 r8 r9", "rax = -errno"),
 "Linux_x86_32":  ("int 0x80", "eax", "ebx ecx edx esi edi ebp", "eax = -errno"),
 "Linux_ARM64":   ("svc #0", "x8", "x0-x5", "x0 = -errno"),
 "Linux_ARM32":   ("svc #0", "r7", "r0-r6", "r0 = -errno"),
 "macOS_ARM64":   ("svc #0x80", "x16", "x0-x5", "carry set, x0 = errno"),
 "macOS_x64":     ("syscall", "rax (0x2000000 + n)", "rdi rsi rdx r10 r8 r9", "carry set, rax = errno"),
 "Windows_x64":   ("syscall", "eax (SSN, unstable)", "rcx->r10 rdx r8 r9, stack", "NTSTATUS in eax"),
 "Windows_ARM64": ("svc #N", "immediate of svc (unstable)", "x0-x7, stack", "NTSTATUS in x0"),
}
# syscall name -> number per platform ("-" = not used / no such call)
NUMS = {
 "write":  {"Linux_x64":"1","Linux_x86_32":"4","Linux_ARM64":"64","Linux_ARM32":"4","macOS_ARM64":"4","macOS_x64":"0x2000004","Windows_x64":"NtWriteFile (SSN varies)","Windows_ARM64":"NtWriteFile (SSN varies)"},
 "read":   {"Linux_x64":"0","Linux_x86_32":"3","Linux_ARM64":"63","Linux_ARM32":"3","macOS_ARM64":"3","macOS_x64":"0x2000003","Windows_x64":"NtReadFile","Windows_ARM64":"NtReadFile"},
 "open":   {"Linux_x64":"2","Linux_x86_32":"5","Linux_ARM64":"56 (openat only)","Linux_ARM32":"5","macOS_ARM64":"5","macOS_x64":"0x2000005","Windows_x64":"NtCreateFile / NtOpenFile","Windows_ARM64":"NtCreateFile / NtOpenFile"},
 "close":  {"Linux_x64":"3","Linux_x86_32":"6","Linux_ARM64":"57","Linux_ARM32":"6","macOS_ARM64":"6","macOS_x64":"0x2000006","Windows_x64":"NtClose","Windows_ARM64":"NtClose"},
 "getpid": {"Linux_x64":"39","Linux_x86_32":"20","Linux_ARM64":"172","Linux_ARM32":"20","macOS_ARM64":"20","macOS_x64":"0x2000014","Windows_x64":"NtQueryInformationProcess","Windows_ARM64":"NtQueryInformationProcess"},
 "mmap":   {"Linux_x64":"9","Linux_x86_32":"192 (mmap2)","Linux_ARM64":"222","Linux_ARM32":"192 (mmap2)","macOS_ARM64":"197","macOS_x64":"0x20000C5","Windows_x64":"NtAllocateVirtualMemory","Windows_ARM64":"NtAllocateVirtualMemory"},
 "munmap": {"Linux_x64":"11","Linux_x86_32":"91","Linux_ARM64":"215","Linux_ARM32":"91","macOS_ARM64":"73","macOS_x64":"0x2000049","Windows_x64":"NtFreeVirtualMemory","Windows_ARM64":"NtFreeVirtualMemory"},
 "exit":   {"Linux_x64":"60","Linux_x86_32":"1","Linux_ARM64":"93","Linux_ARM32":"1","macOS_ARM64":"1","macOS_x64":"0x2000001","Windows_x64":"NtTerminateProcess","Windows_ARM64":"NtTerminateProcess"},
}
# C-library programs: one source file per platform
LIBFILES = {"Windows_x64": ["libc_calls.asm"], "Windows_ARM64": ["libc_calls.asm"],
            "Linux_x64": ["libc_calls.asm"], "Linux_x86_32": ["libc_calls.asm"],
            "Linux_ARM64": ["libc_calls.s"], "Linux_ARM32": ["libc_calls.s"],
            "macOS_ARM64": ["libc_calls.s"], "macOS_x64": ["libc_calls.asm"]}
LIBCONV = {
 "Linux_x64": "SysV: rdi rsi rdx rcx r8 r9; al = 0 for printf; rsp 16-aligned",
 "Linux_x86_32": "cdecl: args on the stack, caller cleans; esp 16-aligned",
 "Linux_ARM64": "AAPCS64: x0-x7; printf args in registers; sp 16-aligned",
 "Linux_ARM32": "AAPCS: r0-r3 then stack; sp 8-aligned",
 "macOS_ARM64": "AAPCS64 but printf variadic args go on the STACK; _ symbol prefix",
 "macOS_x64": "SysV: rdi rsi rdx rcx r8 r9; _ symbol prefix; rsp 16-aligned",
 "Windows_x64": "Microsoft x64: rcx rdx r8 r9 + 32-byte shadow space; rsp 16-aligned",
 "Windows_ARM64": "Windows ARM64: x0-x7; x18 reserved; sp 16-aligned",
}
unix = "fopen/fwrite/fread/fclose"
LIBCALLS = {
 "file I/O":          {p: unix for p in LIBCONV},
 "memory allocation": {p: "malloc / free" for p in LIBCONV},
 "create a process":  {p: ("CreateProcessA + WaitForSingleObject + GetExitCodeProcess" if p.startswith("Windows") else "fork + execv + waitpid") for p in LIBCONV},
 "executable memory": {p: ("VirtualAlloc(PAGE_EXECUTE_READWRITE)" + (" + FlushInstructionCache" if p=="Windows_ARM64" else "") if p.startswith("Windows") else ("mmap(MAP_JIT) + pthread_jit_write_protect_np + sys_icache_invalidate" if p=="macOS_ARM64" else "mmap(PROT_EXEC)" + (" + __clear_cache" if "ARM" in p and p.startswith("Linux") else ""))) for p in LIBCONV},
}
entries = []
for folder, os_, arch, files in PLATFORMS:
    for f in files:
        entries.append(dict(id=f"{folder}/{f}", kind="syscall", dir="Syscalls", folder=folder, os=os_, arch=arch, file=f,
                            code=(root/"Syscalls"/folder/f).read_text(encoding="utf-8")))
    for f in LIBFILES[folder]:
        entries.append(dict(id=f"Libc/{folder}/{f}", kind="libc", dir="Libc", folder=folder, os=os_, arch=arch, file=f,
                            code=(root/"Libc"/folder/f).read_text(encoding="utf-8")))
data = dict(entries=entries, info=INFO, nums=NUMS, libconv=LIBCONV, libcalls=LIBCALLS,
            platforms=[dict(folder=p[0], os=p[1], arch=p[2]) for p in PLATFORMS])
html = (here/"viewer_template.html").read_text(encoding="utf-8")
out = html.replace("/*DATA*/null", json.dumps(data).replace("</", "<\\/"))
(here/"index.html").write_text(out, encoding="utf-8")
print("wrote", here/"index.html", len(out)//1024, "KB")
