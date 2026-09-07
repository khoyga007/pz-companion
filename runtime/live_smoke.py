# SPDX-License-Identifier: Apache-2.0
"""Explicit paid check: two DeepSeek calls through the Lua/file/Python round trip."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def wait_for(path, process):
    deadline = time.monotonic() + 45
    while not path.exists():
        if process.poll() is not None or time.monotonic() > deadline:
            raise RuntimeError("Integration process exited or timed out")
        time.sleep(0.1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key-file", type=Path, required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="pz-deepseek-") as directory:
        root = Path(directory)
        with (root / "service.log").open("w", encoding="utf-8") as log:
            service = subprocess.Popen([sys.executable, str(repo / "runtime/deepseek.py"),
                "--key-file", str(args.key_file), "--pz-user-dir", str(root), "--max-requests", "2"],
                stdout=log, stderr=log)
            try:
                ipc = root / "WHG_PZ_Companion/ipc"
                wait_for(ipc / "runtime/status.json", service)
                for i, (message, expected) in enumerate([
                    ("Căn cứ mình tên Đồi Thông. Đi theo anh nhé.", "FOLLOW"),
                    ("Căn cứ mình tên gì? Đứng chờ anh ở đây nhé.", "WAIT"),
                ]):
                    id_file = root / f"id-{i}.txt"
                    driver = subprocess.Popen(["lua", "tests/live_transport.lua", str(root), str(id_file),
                        message, "live-smoke-companion"], cwd=repo, stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8")
                    try:
                        wait_for(id_file, driver)
                        request_id = id_file.read_text()
                        wait_for(ipc / f"responses/{request_id}.response.json", service)
                        stdout, stderr = driver.communicate("\n", timeout=10)
                        if driver.returncode:
                            raise RuntimeError("Lua round trip failed: " + stderr)
                        reply = json.loads(stdout)
                        assert reply["intent"] == expected, "Unexpected model intent"
                        if i == 1:
                            assert "đồi thông" in reply["speech"].casefold(), "Memory recall failed"
                        print(f"PASS round trip {i+1}: {expected}; speech={reply['speech']}")
                    finally:
                        if driver.poll() is None:
                            driver.kill()
                            driver.communicate()
            finally:
                service.terminate()
                service.wait(timeout=10)


if __name__ == "__main__":
    main()
