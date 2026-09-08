#!/usr/bin/env python3
"""Deliver STOP on either side of runtime-child creation, before PID assignment."""

import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile

source = Path(sys.argv[1]).read_text()
for anchor in ['"$TFT_RUNTIME_PROJECT/scripts/run-asg-experiment.command" >>', 'child_pid=$!']:
    assert source.count(anchor) == 1
    with tempfile.TemporaryDirectory(prefix="mactician-early-stop-") as temporary:
        root = Path(temporary)
        (root / "scripts").mkdir()
        (root / "scripts/run-asg-experiment.command").symlink_to("/usr/bin/caffeinate")
        runtime = root / "runtime.command"
        runtime.write_text(source.replace(anchor, "kill -TERM $$\n" + anchor, 1))
        environment = dict(os.environ, TFT_RUNTIME_PROJECT=str(root),
                           TFT_LAUNCH_LOG=str(root / "runtime.log"), TFT_ADB="/usr/bin/false",
                           TFT_AVD_HOME=str(root / "avd"), TFT_AVD_NAME="Tft",
                           TFT_SERIAL="emulator-5582", TFT_DISPLAY_SIZE="1920x1080",
                           TFT_DISPLAY_DENSITY="320", TFT_GAME_LANGUAGE="en-US",
                           TFT_CPU_CORES="6", TFT_MEMORY_MB="6144", TFT_UI_SCALE="1.0",
                           TFT_PERFORMANCE_MODE="0")
        process = subprocess.Popen(["/bin/zsh", str(runtime)], env=environment,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   text=True, start_new_session=True)
        try:
            stdout, stderr = process.communicate(timeout=5)
            assert process.returncode == 0, (stdout, stderr)
            assert '"event":"stopped"' in stdout and '"event":"error"' not in stdout, stdout
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()

print("Immediate runtime STOP before child PID assignment: OK")
