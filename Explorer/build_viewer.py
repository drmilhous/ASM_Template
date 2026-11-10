#!/usr/bin/env python3
"""Regenerates index.html (the searchable syscall / C-library explorer) from the example sources.
Usage: python3 Explorer/build_viewer.py      (run from anywhere; writes next to this script)"""
import json, pathlib, re
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
def comment_style(folder, f):
    if f.endswith(".asm"): return ";"
    return "@" if folder == "Linux_ARM32" else "//"

INVOKE = re.compile(r"^\s*(syscall|int\s+0x80|svc\s+#0x80|svc\s+#0)\b")
STOP_WORDS = {"call","bl","blr","b","jmp","ret","test","cmp","cmn","js","jz","jnz","jc","je","jne","ja","tbnz","cbz","cbnz","bcs","bhi","blt","beq","bne","bx","blx","b.cs","b.hi","b.eq","b.ne","b.lt","b.hs"}
CHECKS = {"test","cmp","cmn","js","jz","jnz","jc","je","ja","tbnz","cbz","cbnz","bcs","bhi","blt","b.cs","b.hi","b.lt","b.eq","b.ne"}
STEP = re.compile(r"^\s+(;|//|@)\s*(\d)\.\s+(.*?)\s*$")

def first_word(line):
    t = line.strip().split(None, 1)
    return t[0].lower() if t else ""

def is_plain(line):
    st = line.strip()
    if not st or st.startswith((";", "//", "@")): return False
    if re.match(r"^[.\w$]+:", st): return False
    w = first_word(line)
    return w not in STOP_WORDS and not w.startswith(".") and w not in ("segment","section","global")

def syscall_snippets(lines):
    out, seen = [], set()
    for i, l in enumerate(lines):
        if not INVOKE.match(l): continue
        a = i
        while a > 0 and is_plain(lines[a-1]): a -= 1
        b = i
        while b + 1 < len(lines) and first_word(lines[b+1]) in CHECKS and b - i < 2: b += 1
        text = "\n".join(lines[a:b+1])
        m = re.findall(r"SYS_(\w+)", text)
        title = m[0] if m else "syscall stub"
        if title in seen: continue
        seen.add(title)
        out.append(dict(title=title, start=a+1, end=b+1))
    return out

def step_snippets(lines):
    marks = [(i, STEP.match(l)) for i, l in enumerate(lines)]
    marks = [(i, m) for i, m in marks if m]
    out = []
    for n, (i, m) in enumerate(marks):
        end = marks[n+1][0] if n + 1 < len(marks) else None
        if end is None:  # last step ends at the failure/epilogue label, minus the success epilogue
            end = next((j for j in range(i+2, len(lines)) if re.match(r"^\.?(fail|done)\b", lines[j].strip())), len(lines))
            tail = re.compile(r"^\s*(xor\s+eax, eax|mov\s+eax, 0|jmp\s+\.done|b\s+done|mov\s+[wr]0, #0|)\s*(;.*|//.*|@.*)?$")
            while end > i + 2 and tail.match(lines[end-1]): end -= 1
        out.append(dict(title=m.group(3), start=i+1, end=end))
    return out

def snippets_for(kind, folder, f, code):
    lines = code.split("\n")
    if kind == "syscall" and not f.endswith("_api.asm"):
        return syscall_snippets(lines)
    return step_snippets(lines)

# ---- API documentation links (man7.org for Linux, FreeBSD man pages for macOS (BSD-derived,
# closest public pages; also run `man 2 write` on the Mac), Microsoft Learn for Windows)
def m7(sec, name): return f"https://man7.org/linux/man-pages/man{sec}/{name}.{sec}.html"
def bsd(sec, name): return f"https://man.freebsd.org/cgi/man.cgi?query={name}&sektion={sec}"
UNIX_FN = {"write":2,"read":2,"open":2,"openat":2,"close":2,"getpid":2,"mmap":2,"munmap":2,"fork":2,"waitpid":2,
           "execv":3,"fopen":3,"fwrite":3,"fread":3,"fclose":3,"fflush":3,"malloc":3,"free":3,"puts":3,"printf":3}
DOCS = {"Linux": {}, "macOS": {}, "Windows": {}}
for n, sec in UNIX_FN.items():
    DOCS["Linux"][n] = [f"{n}({sec})", m7(sec, n)]
    if n != "openat": DOCS["macOS"][n] = [f"{n}({sec})", bsd(sec, n)]
DOCS["macOS"]["openat"] = ["openat(2)", bsd(2, "openat")]
DOCS["Linux"]["mmap2"] = ["mmap2(2)", m7(2, "mmap2")]
DOCS["Linux"]["exit"] = ["_exit(2)", m7(2, "_exit")]
DOCS["macOS"]["exit"] = ["_exit(2)", bsd(2, "_exit")]
DOCS["macOS"]["_exit"] = DOCS["macOS"]["exit"]
DOCS["Linux"]["_exit"] = DOCS["Linux"]["exit"]
DOCS["Linux"]["__clear_cache"] = ["__builtin___clear_cache", "https://gcc.gnu.org/onlinedocs/gcc/Other-Builtins.html"]
for k in ("pthread_jit_write_protect_np", "sys_icache_invalidate"):
    DOCS["macOS"][k] = [k, "https://developer.apple.com/documentation/apple-silicon/porting-just-in-time-compilers-to-apple-silicon"]
W = "https://learn.microsoft.com/en-us/windows/win32/api/"
DOCS["Windows"].update({
 "GetStdHandle": ["GetStdHandle", W+"processenv/nf-processenv-getstdhandle"],
 "WriteFile": ["WriteFile", W+"fileapi/nf-fileapi-writefile"],
 "ReadFile": ["ReadFile", W+"fileapi/nf-fileapi-readfile"],
 "CreateFileA": ["CreateFileA", W+"fileapi/nf-fileapi-createfilea"],
 "CloseHandle": ["CloseHandle", W+"handleapi/nf-handleapi-closehandle"],
 "GetCurrentProcessId": ["GetCurrentProcessId", W+"processthreadsapi/nf-processthreadsapi-getcurrentprocessid"],
 "GetCurrentProcess": ["GetCurrentProcess", W+"processthreadsapi/nf-processthreadsapi-getcurrentprocess"],
 "VirtualAlloc": ["VirtualAlloc", W+"memoryapi/nf-memoryapi-virtualalloc"],
 "VirtualFree": ["VirtualFree", W+"memoryapi/nf-memoryapi-virtualfree"],
 "ExitProcess": ["ExitProcess", W+"processthreadsapi/nf-processthreadsapi-exitprocess"],
 "CreateProcessA": ["CreateProcessA", W+"processthreadsapi/nf-processthreadsapi-createprocessa"],
 "WaitForSingleObject": ["WaitForSingleObject", W+"synchapi/nf-synchapi-waitforsingleobject"],
 "GetExitCodeProcess": ["GetExitCodeProcess", W+"processthreadsapi/nf-processthreadsapi-getexitcodeprocess"],
 "GetModuleHandleA": ["GetModuleHandleA", W+"libloaderapi/nf-libloaderapi-getmodulehandlea"],
 "GetProcAddress": ["GetProcAddress", W+"libloaderapi/nf-libloaderapi-getprocaddress"],
 "FlushInstructionCache": ["FlushInstructionCache", W+"processthreadsapi/nf-processthreadsapi-flushinstructioncache"],
 "NtWriteFile": ["NtWriteFile", "https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/nf-ntifs-ntwritefile"],
 "NtTerminateProcess": ["ZwTerminateProcess (NtTerminateProcess)", "https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntddk/nf-ntddk-zwterminateprocess"],
 "NtQueryInformationProcess": ["NtQueryInformationProcess", W+"winternl/nf-winternl-ntqueryinformationprocess"],
})
CRT = "https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/"
for n, p in {"fopen":"fopen-wfopen","fwrite":"fwrite","fread":"fread","fclose":"fclose-fcloseall","fflush":"fflush","malloc":"malloc","free":"free","puts":"puts-putws","printf":"printf-printf-l-wprintf-wprintf-l"}.items():
    DOCS["Windows"][n] = [n + " (C runtime)", CRT + p]

entries = []
for folder, os_, arch, files in PLATFORMS:
    for f in files:
        entries.append(dict(id=f"{folder}/{f}", kind="syscall", dir="Syscalls", folder=folder, os=os_, arch=arch, file=f, cm=comment_style(folder, f),
                            code=(c := (root/"Syscalls"/folder/f).read_text(encoding="utf-8")),
                            snippets=snippets_for("syscall", folder, f, c)))
    for f in LIBFILES[folder]:
        entries.append(dict(id=f"Libc/{folder}/{f}", kind="libc", dir="Libc", folder=folder, os=os_, arch=arch, file=f, cm=comment_style(folder, f),
                            code=(c := (root/"Libc"/folder/f).read_text(encoding="utf-8")),
                            snippets=snippets_for("libc", folder, f, c)))
data = dict(entries=entries, info=INFO, nums=NUMS, libconv=LIBCONV, docs=DOCS, libcalls=LIBCALLS,
            platforms=[dict(folder=p[0], os=p[1], arch=p[2]) for p in PLATFORMS])
html = (here/"viewer_template.html").read_text(encoding="utf-8")
html = html.replace("/*FONTS*/", (here/"fonts.css").read_text(encoding="utf-8"))
out = html.replace("/*DATA*/null", json.dumps(data).replace("</", "<\\/"))
(here/"index.html").write_text(out, encoding="utf-8")
print("snippets:", sum(len(e["snippets"]) for e in entries))
print("wrote", here/"index.html", len(out)//1024, "KB")
