"""Merge the public Whisper Seamless profile into the user's local config."""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
import os
import re
import shutil

from ruamel.yaml import YAML


def merge_dict(base: dict, updates: dict) -> None:
    for key, value in updates.items():
        if isinstance(value, dict):
            node = base.get(key)
            if not isinstance(node, dict):
                node = {}
                base[key] = node
            merge_dict(node, value)
        else:
            base[key] = value


def normalize_hotkey(value: str) -> str:
    hotkey = value.strip().lower().replace(" ", "")
    parts = [part for part in hotkey.split("+") if part]
    if not parts:
        raise ValueError("Hotkey cannot be empty")

    key = parts[-1]
    modifiers = parts[:-1]
    valid_modifiers = {"ctrl", "alt", "shift", "win"}
    if len(set(modifiers)) != len(modifiers) or any(m not in valid_modifiers for m in modifiers):
        raise ValueError(f"Unsupported modifier in hotkey: {value}")

    function_key = re.fullmatch(r"f([1-9]|1[0-9]|2[0-4])", key)
    simple_key = re.fullmatch(r"[a-z0-9]", key) or key == "space"
    if not function_key and not simple_key:
        raise ValueError(
            "Hotkey key must be F1-F24, A-Z, 0-9 or Space; "
            "letters/digits/Space may be combined with Ctrl/Alt/Shift/Win"
        )
    if simple_key and not modifiers:
        raise ValueError("Bare letters, digits and Space are not allowed; add a modifier")

    return "+".join(parts)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--recording-hotkey", default="f24")
    args = parser.parse_args()
    recording_hotkey = normalize_hotkey(args.recording_hotkey)

    appdata = Path(os.environ["APPDATA"])
    cfg_dir = appdata / "whisperkey"
    cfg_dir.mkdir(parents=True, exist_ok=True)
    cfg = cfg_dir / "user_settings.yaml"

    yaml = YAML()
    yaml.preserve_quotes = True

    data = {}
    if cfg.exists():
        backup_dir = cfg_dir / "backups"
        backup_dir.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        shutil.copy2(cfg, backup_dir / f"user_settings-before-seamless-{stamp}.yaml")
        with cfg.open("r", encoding="utf-8") as f:
            loaded = yaml.load(f)
            if isinstance(loaded, dict):
                data = loaded

    updates = {
        "whisper": {
            "backend": "faster_whisper",
            "model": "large-v3-turbo",
            "device": "cuda",
            "compute_type": "float16",
            "language": "auto",
            "task": "transcribe",
        },
        "streaming": {"streaming_enabled": False, "deliver_to_cursor": False},
        "hotkey": {
            "recording_hotkey": recording_hotkey,
            "recording_mode": "toggle",
            "cancel_combination": "esc",
        },
        "vad": {
            "vad_precheck_enabled": True,
            "vad_realtime_enabled": False,
        },
        "audio": {
            "host": "MME",
            "channels": 1,
            "continuous_mode": True,
            "dtype": "float32",
            "max_duration": 30,
            "input_device": "default",
            "pause_media_on_record": False,
        },
        "clipboard": {
            "auto_paste": True,
            "delivery_method": "paste",
            "paste_preserve_clipboard": True,
        },
    }

    merge_dict(data, updates)

    with cfg.open("w", encoding="utf-8") as f:
        yaml.dump(data, f)

    (cfg_dir / "first_run_complete.txt").write_text("ok", encoding="utf-8")
    print(f"Configured: {cfg}")
    print(
        "Profile: large-v3-turbo / CUDA float16 / "
        f"{recording_hotkey.upper()} / MME / continuous 30 s"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
