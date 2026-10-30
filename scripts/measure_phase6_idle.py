#!/usr/bin/env python3
"""Observe only the disposable Phase 6 review process; never alters settings."""
import ctypes
import json
import pathlib
import subprocess
import sys
import time

matches = []
for line in subprocess.check_output(["/bin/ps", "-axo", "pid=,comm="], text=True).splitlines():
    fields = line.strip().split(None, 1)
    if len(fields) == 2 and fields[1].endswith("NivletPhase6Review.app/Contents/MacOS/NivletPhase6Review"):
        matches.append(int(fields[0]))
if len(matches) != 1:
    raise SystemExit("Exactly one isolated review app must be running")
pid = matches[0]

class Usage(ctypes.Structure):
    _fields_ = [("uuid", ctypes.c_uint8 * 16)] + [(name, ctypes.c_uint64) for name in (
        "user", "system", "package_wakeups", "interrupt_wakeups", "pageins", "wired", "resident", "footprint", "start", "exit")]

lib = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
lib.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]

def usage():
    result = Usage()
    if lib.proc_pid_rusage(pid, 0, ctypes.byref(result)):
        raise OSError(ctypes.get_errno(), "proc_pid_rusage")
    return result

class Timebase(ctypes.Structure):
    _fields_ = [("numer", ctypes.c_uint32), ("denom", ctypes.c_uint32)]

timebase = Timebase()
ctypes.CDLL("/usr/lib/libSystem.B.dylib").mach_timebase_info(ctypes.byref(timebase))
seconds_per_tick = timebase.numer / timebase.denom / 1e9

start = usage()
started = time.monotonic()
samples = []
previous = start
previous_time = started
for _ in range(30):
    time.sleep(1)
    current = usage()
    now = time.monotonic()
    samples.append(100 * ((current.user + current.system) - (previous.user + previous.system)) * seconds_per_tick / (now - previous_time))
    previous, previous_time = current, now
elapsed = previous_time - started
cpu_seconds = ((previous.user + previous.system) - (start.user + start.system)) * seconds_per_tick
network = subprocess.run(["/usr/sbin/lsof", "-a", "-p", str(pid), "-i", "-nP"], text=True, capture_output=True)
report = {"metric": "idle-cpu", "wall_seconds": elapsed, "cpu_seconds": cpu_seconds,
          "mean_percent_one_core": cpu_seconds / elapsed * 100, "sample_count": len(samples), "timebase_numer": timebase.numer, "timebase_denom": timebase.denom,
          "samples_percent_one_core": samples, "socket_rows": network.stdout.splitlines(),
          "socket_check_exit": network.returncode, "socket_check_had_stderr": bool(network.stderr), "resident_bytes_end": previous.resident}
pathlib.Path(sys.argv[1]).write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({key: value for key, value in report.items() if key != "samples_percent_one_core"}))
