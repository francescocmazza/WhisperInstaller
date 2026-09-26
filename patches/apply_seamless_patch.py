"""
Patch Whisper Local 0.18.3 for gapless max-duration rollover.

Safety:
- Requires exactly whisper-local 0.18.3.
- Uses exact one-occurrence source replacements.
- Creates .seamless-original backups before changing source.
- Idempotent: if marker is present, exits successfully.
"""

from __future__ import annotations

import importlib.metadata
import importlib.util
from pathlib import Path
import py_compile
import shutil
import sys

EXPECTED_VERSION = "0.18.3"
MARKER = "# WHISPER_SEAMLESS_ROLLOVER_PATCH_V1"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"{label}: expected exactly 1 source match, found {count}. "
            "Source does not match the pinned Whisper Local 0.18.3 layout."
        )
    return text.replace(old, new, 1)


def package_dir() -> Path:
    spec = importlib.util.find_spec("whisper_key")
    if not spec or not spec.submodule_search_locations:
        raise RuntimeError("whisper_key package not found")
    return Path(next(iter(spec.submodule_search_locations)))


def main() -> int:
    version = importlib.metadata.version("whisper-local")
    if version != EXPECTED_VERSION:
        raise RuntimeError(
            f"Expected whisper-local {EXPECTED_VERSION}, found {version}. "
            "No patch applied."
        )

    pkg = package_dir()
    state_path = pkg / "state_manager.py"
    audio_path = pkg / "audio_recorder.py"

    state = state_path.read_text(encoding="utf-8")
    audio = audio_path.read_text(encoding="utf-8")

    if MARKER in state and MARKER in audio:
        print("Seamless patch already applied.")
        return 0

    for path in (state_path, audio_path):
        backup = path.with_suffix(path.suffix + ".seamless-original")
        if not backup.exists():
            shutil.copy2(path, backup)

    old = """        with self._buffer_lock:
            snapshot = list(self._buffer)
            self.is_recording = False
            self._buffer.clear()
        audio_data = self._build_audio_array(snapshot)
        if self.on_max_duration_reached:
            self.on_max_duration_reached(audio_data)
        return True
"""
    new = f"""        {MARKER}
        # Snapshot the completed segment but KEEP the live capture active.
        # PortAudio's callback immediately fills the empty buffer for the next
        # segment while the previous snapshot is prepared/transcribed.
        with self._buffer_lock:
            snapshot = list(self._buffer)
            self._buffer.clear()
            self.recording_start_time = time.time()
        audio_data = self._build_audio_array(snapshot)
        if self.on_max_duration_reached:
            self.on_max_duration_reached(audio_data)
        return True
"""
    audio = replace_once(audio, old, new, "audio seamless rollover")

    old = """        audio_array = self._trim_long_pauses(audio_array)
        audio_array = self._trim_trailing_silence(audio_array)
"""
    new = """        # Seamless profile: do not splice silence out of the MIDDLE of audio.
        # That operation can cut phonemes/words on both sides of a pause.
        audio_array = self._trim_trailing_silence(audio_array)
"""
    audio = replace_once(audio, old, new, "disable interior pause splicing")

    old = """        self._state_lock = threading.Lock()
"""
    new = f"""        self._state_lock = threading.Lock()
        {MARKER}
        # Audio capture and transcription may overlap, but transcript delivery
        # stays serialized so chunks reach the cursor in spoken order.
        self._transcription_lock = threading.Lock()
"""
    state = replace_once(state, old, new, "transcription lock")

    old = """        self._begin_recording()

    def set_paused(self, paused: bool):
"""
    new = """        # A fresh explicit start begins a new continuous session.
        self._continuous_aborted = False
        self._begin_recording()

    def set_paused(self, paused: bool):
"""
    state = replace_once(state, old, new, "continuous session start")

    old = """    def _maybe_restart_continuous(self):
        audio_cfg = self.config_manager.config.get('audio', {})
        if not audio_cfg.get('continuous_mode', False) or self.is_paused:
            return
        self._continuous_aborted = False
        import threading
        def restart():
            import time
            time.sleep(0.6)
            if self.is_paused or self._continuous_aborted:
                self.logger.info("Continuous mode: restart aborted")
                return
            if not self.audio_recorder.get_recording_status():
                self.logger.info("Continuous mode: auto-restarting recording")
                self._begin_recording()
        threading.Thread(target=restart, daemon=True, name='continuous-restart').start()
"""
    new = """    def _maybe_restart_continuous(self):
        audio_cfg = self.config_manager.config.get('audio', {})
        if (not audio_cfg.get('continuous_mode', False)
                or self.is_paused
                or self._continuous_aborted):
            return

        if self.audio_recorder.get_recording_status():
            return

        import threading
        def restart():
            import time
            time.sleep(0.05)
            if self.is_paused or self._continuous_aborted:
                self.logger.info("Continuous mode: restart aborted")
                return
            if not self.audio_recorder.get_recording_status():
                self.logger.info("Continuous mode: auto-restarting recording")
                self._begin_recording()
        threading.Thread(target=restart, daemon=True, name='continuous-restart').start()
"""
    state = replace_once(state, old, new, "continuous restart")

    old = """    def _transcription_pipeline(self, audio_data, use_auto_enter: bool = False):
        try:
"""
    new = """    def _transcription_pipeline(self, audio_data, use_auto_enter: bool = False):
        # A rollover keeps segment N+1 recording while segment N is processed.
        # Serialize processing/delivery workers to preserve spoken order.
        self._transcription_lock.acquire()
        recording_continues = self.audio_recorder.get_recording_status()
        try:
"""
    state = replace_once(state, old, new, "pipeline serialization")

    old = """            self.audio_feedback.play_stop_sound()
"""
    new = """            # Do not play a stop clip at an automatic rollover: capture is
            # still live and the clip itself could be recorded by the mic.
            if not recording_continues:
                self.audio_feedback.play_stop_sound()
"""
    state = replace_once(state, old, new, "suppress rollover stop sound")

    old = """            self._update_ui_state("processing")
            if self.level_overlay:
                self.level_overlay.show_processing()
"""
    new = """            # During seamless rollover processing and recording overlap.
            if not recording_continues:
                self._update_ui_state("processing")
                if self.level_overlay:
                    self.level_overlay.show_processing()
            else:
                self._update_ui_state("recording")
                if self.level_overlay:
                    self.level_overlay.show_recording()
"""
    state = replace_once(state, old, new, "recording UI during rollover")

    old = """            if not (pending_device or pending_model):
                self._update_ui_state("idle")
"""
    new = """            if not (pending_device or pending_model):
                if self.audio_recorder.get_recording_status():
                    self._update_ui_state("recording")
                    if self.level_overlay:
                        self.level_overlay.show_recording()
                else:
                    self._update_ui_state("idle")

            self._transcription_lock.release()
"""
    state = replace_once(state, old, new, "pipeline final UI and unlock")

    old = """    def get_current_state(self) -> str:
        with self._state_lock:
            if self.is_model_loading:
                return "model_loading"
            elif self.is_processing:
                return "processing"
            elif self.audio_recorder.get_recording_status():
                return "recording"
            else:
                return "idle"
"""
    new = """    def get_current_state(self) -> str:
        with self._state_lock:
            if self.is_model_loading:
                return "model_loading"
            elif self.audio_recorder.get_recording_status():
                return "recording"
            elif self.is_processing:
                return "processing"
            else:
                return "idle"
"""
    state = replace_once(state, old, new, "state priority")

    audio_path.write_text(audio, encoding="utf-8")
    state_path.write_text(state, encoding="utf-8")

    try:
        py_compile.compile(str(audio_path), doraise=True)
        py_compile.compile(str(state_path), doraise=True)
    except Exception:
        for path in (state_path, audio_path):
            backup = path.with_suffix(path.suffix + ".seamless-original")
            if backup.exists():
                shutil.copy2(backup, path)
        raise

    print("Seamless rollover patch applied and syntax-checked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
