"""Patch Whisper Local 0.18.3 tray utility windows so their subprocesses stay alive.

Whisper Local launches Transcript History and Hotkey Cheat Sheet in dedicated
subprocesses. Both utilities create their Tk root on daemon threads, while the
CLI process exits after a short sleep. A daemon thread cannot keep the process
alive, so the window flashes briefly and disappears.

This patch changes only those utility-window threads to non-daemon threads.
It is version-pinned, exact-match, idempotent, syntax-checked, and backed up.
"""

from __future__ import annotations

import importlib.metadata
import importlib.util
from pathlib import Path
import py_compile
import shutil

EXPECTED_VERSION = "0.18.3"
MARKER = "# WHISPER_SEAMLESS_WINDOW_LIFETIME_PATCH_V1"


def package_dir() -> Path:
    spec = importlib.util.find_spec("whisper_key")
    if not spec or not spec.submodule_search_locations:
        raise RuntimeError("whisper_key package not found")
    return Path(next(iter(spec.submodule_search_locations)))


def patch_file(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    if MARKER in text:
        print(f"{label}: already patched")
        return

    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"{label}: expected exactly 1 source match, found {count}. "
            "Source does not match pinned Whisper Local 0.18.3."
        )

    backup = path.with_suffix(path.suffix + ".window-lifetime-original")
    if not backup.exists():
        shutil.copy2(path, backup)

    patched = text.replace(old, new, 1)
    path.write_text(patched, encoding="utf-8")

    try:
        py_compile.compile(str(path), doraise=True)
    except Exception:
        shutil.copy2(backup, path)
        raise


def main() -> int:
    version = importlib.metadata.version("whisper-local")
    if version != EXPECTED_VERSION:
        raise RuntimeError(
            f"Expected whisper-local {EXPECTED_VERSION}, found {version}. "
            "No window-lifetime patch applied."
        )

    pkg = package_dir()

    patch_file(
        pkg / "history_window.py",
        "    threading.Thread(target=_run, daemon=True, name='history-window').start()\n",
        f"    {MARKER}\n"
        "    # This utility is launched in its own subprocess. A non-daemon Tk\n"
        "    # thread keeps that subprocess alive until the user closes the window.\n"
        "    threading.Thread(target=_run, daemon=False, name='history-window').start()\n",
        "Transcript History window",
    )

    patch_file(
        pkg / "cheat_sheet.py",
        """    threading.Thread(
        target=_run,
        args=(config_manager, transforms_manager),
        daemon=True,
        name='cheat-sheet',
    ).start()
""",
        f"""    {MARKER}
    # This utility is launched in its own subprocess. Keep the process alive
    # until the user closes the Tk window.
    threading.Thread(
        target=_run,
        args=(config_manager, transforms_manager),
        daemon=False,
        name='cheat-sheet',
    ).start()
""",
        "Hotkey cheat sheet window",
    )

    print("Tray utility window lifetime patch applied and syntax-checked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
