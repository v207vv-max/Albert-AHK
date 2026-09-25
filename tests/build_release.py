"""Build a source-only handoff; never copy operator settings or logs."""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
subprocess.run([sys.executable, str(root / "tests/check_logic.py")], check=True)
source = (root / "release" / "Albert-V2.ahk").read_text(encoding="utf-8-sig")
assert "ZikSendCommand" not in source and "127.0.0.1:8765" not in source
assert "C:\\Users\\Asko" not in source
assert "PgUp::" not in source
release = root / "release"
release.mkdir(exist_ok=True)
for name in ("README_RELEASE.md",):
    shutil.copy2(root / name, release / name)
print(f"Source release: {release}")
