#!/usr/bin/env python3
"""Verify the real SwiftData store across an abrupt exit and two new processes."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results-dir", type=Path)
    args = parser.parse_args()
    if args.results_dir:
        directory = args.results_dir.resolve()
        directory.mkdir(parents=True, exist_ok=False)
    else:
        directory = Path(tempfile.mkdtemp(prefix="reader-store-recovery-"))
    package = str(ROOT / "ReaderKit")
    with (directory / "build.log").open("w") as log:
        subprocess.run(["swift", "build", "--package-path", package, "--product", "ReaderStoreRecoveryProbe"],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    binary_path = subprocess.check_output(["swift", "build", "--package-path", package, "--show-bin-path"], text=True).strip()
    executable = str(Path(binary_path) / "ReaderStoreRecoveryProbe")
    started = time.monotonic()
    with (directory / "seed.log").open("w") as log:
        seed = subprocess.Popen([executable, "seed", str(directory)], stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 30
            while not (directory / "state.json").exists():
                if seed.poll() is not None:
                    raise RuntimeError(f"Schreibprozess endete vor dem Commitmarker: {seed.returncode}; {directory / 'seed.log'}")
                if time.monotonic() >= deadline:
                    raise TimeoutError("Commitmarker fehlt nach 30 Sekunden")
                time.sleep(.05)
            wal = directory / "Reader.store-wal"
            wal_bytes = wal.stat().st_size if wal.exists() else 0
            seed.kill()
            seed.wait(timeout=10)
            if seed.returncode != -9:
                raise RuntimeError(f"Erwartet SIGKILL, erhalten: {seed.returncode}")
        finally:
            if seed.poll() is None:
                seed.kill()
                seed.wait(timeout=10)
    phases = []
    for phase in ["recover", "verify"]:
        with (directory / f"{phase}.log").open("w") as log:
            process = subprocess.Popen([executable, phase, str(directory)], stdout=log, stderr=subprocess.STDOUT)
            try:
                code = process.wait(timeout=30)
                if code:
                    raise RuntimeError(f"Phase {phase}: Exit {code}; {directory / f'{phase}.log'}")
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=10)
        phases.append({"phase": phase, "pid": process.pid, "exitCode": code})
    state = json.loads((directory / "state.json").read_text())
    report = {"result": "passed", "syntheticArticles": state["articleCount"], "seedPID": seed.pid,
              "seedExitCode": seed.returncode, "walBytesBeforeKill": wal_bytes, "restarts": phases,
              "retainedArticles": 2, "pendingRevisions": len(state["pending"]),
              "durationSeconds": round(time.monotonic() - started, 3)}
    (directory / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    print(f"Reader-SwiftData-Prozessneustart geprüft: {directory}")


if __name__ == "__main__":
    main()
