"""Launch Whisper Local with an optional reversible physical-key binding.

Physical-key mode uses a Windows low-level keyboard hook only for the lifetime
of the Whisper process. It does NOT write Scancode Map, remap the keyboard in
the registry, or modify firmware. Therefore the original Windows key behavior
returns immediately when Whisper exits and necessarily after uninstall.

The primary use case is VK_APPS (0x5D), the Menu / Context Menu key.
"""

from __future__ import annotations

import configparser
import ctypes
from ctypes import wintypes
import logging
import os
from pathlib import Path
import threading

WH_KEYBOARD_LL = 13
HC_ACTION = 0
WM_KEYDOWN = 0x0100
WM_KEYUP = 0x0101
WM_SYSKEYDOWN = 0x0104
WM_SYSKEYUP = 0x0105
WM_QUIT = 0x0012
LLKHF_INJECTED = 0x10

# use_last_error=True is required if we want the Win32 error reported by
# SetWindowsHookEx/GetModuleHandle instead of a stale ctypes error.
user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

LRESULT = ctypes.c_ssize_t
MODULE_HANDLE = getattr(wintypes, "HMODULE", wintypes.HINSTANCE)


class KBDLLHOOKSTRUCT(ctypes.Structure):
    _fields_ = [
        ("vkCode", wintypes.DWORD),
        ("scanCode", wintypes.DWORD),
        ("flags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ctypes.c_void_p),
    ]


HOOKPROC = ctypes.WINFUNCTYPE(
    LRESULT,
    ctypes.c_int,
    wintypes.WPARAM,
    wintypes.LPARAM,
)

user32.SetWindowsHookExW.argtypes = [
    ctypes.c_int,
    HOOKPROC,
    wintypes.HINSTANCE,
    wintypes.DWORD,
]
user32.SetWindowsHookExW.restype = wintypes.HHOOK
user32.CallNextHookEx.argtypes = [
    wintypes.HHOOK,
    ctypes.c_int,
    wintypes.WPARAM,
    wintypes.LPARAM,
]
user32.CallNextHookEx.restype = LRESULT
user32.UnhookWindowsHookEx.argtypes = [wintypes.HHOOK]
user32.UnhookWindowsHookEx.restype = wintypes.BOOL
user32.GetMessageW.argtypes = [
    ctypes.POINTER(wintypes.MSG),
    wintypes.HWND,
    wintypes.UINT,
    wintypes.UINT,
]
user32.GetMessageW.restype = wintypes.BOOL
user32.PostThreadMessageW.argtypes = [
    wintypes.DWORD,
    wintypes.UINT,
    wintypes.WPARAM,
    wintypes.LPARAM,
]
user32.PostThreadMessageW.restype = wintypes.BOOL
kernel32.GetCurrentThreadId.argtypes = []
kernel32.GetCurrentThreadId.restype = wintypes.DWORD
kernel32.GetModuleHandleW.argtypes = [wintypes.LPCWSTR]
kernel32.GetModuleHandleW.restype = MODULE_HANDLE


def _binding_path() -> Path:
    return Path(os.environ["APPDATA"]) / "whisperkey" / "seamless_binding.ini"


def _load_binding() -> tuple[str, int, str]:
    path = _binding_path()
    if not path.exists():
        return "native", 0, ""

    parser = configparser.ConfigParser()
    parser.read(path, encoding="utf-8")
    section = parser["Binding"] if parser.has_section("Binding") else {}
    mode = str(section.get("Mode", "native")).strip().lower()
    try:
        vk = int(str(section.get("VirtualKey", "0")).strip(), 0)
    except ValueError:
        vk = 0
    name = str(section.get("Display", "")).strip()
    return mode, vk, name


class PhysicalKeyHook:
    def __init__(self, virtual_key: int, display_name: str, on_press, on_release):
        self.virtual_key = virtual_key
        self.display_name = display_name or f"VK {virtual_key}"
        self.on_press = on_press
        self.on_release = on_release
        self._hook = None
        self._thread = None
        self._thread_id = 0
        self._ready = threading.Event()
        self._error: Exception | None = None
        self._pressed = False
        self._proc = HOOKPROC(self._callback)
        self.logger = logging.getLogger(__name__)

    @staticmethod
    def _fire(callback):
        if callback is None:
            return
        threading.Thread(target=callback, daemon=True, name="physical-key-action").start()

    def _callback(self, n_code, w_param, l_param):
        if n_code == HC_ACTION:
            data = ctypes.cast(l_param, ctypes.POINTER(KBDLLHOOKSTRUCT)).contents
            if data.vkCode == self.virtual_key and not (data.flags & LLKHF_INJECTED):
                if w_param in (WM_KEYDOWN, WM_SYSKEYDOWN):
                    if not self._pressed:
                        self._pressed = True
                        self._fire(self.on_press)
                    return 1
                if w_param in (WM_KEYUP, WM_SYSKEYUP):
                    if self._pressed:
                        self._pressed = False
                        self._fire(self.on_release)
                    return 1

        return user32.CallNextHookEx(self._hook, n_code, w_param, l_param)

    def _run(self):
        try:
            self._thread_id = kernel32.GetCurrentThreadId()
            # IMPORTANT on 64-bit Windows: GetModuleHandleW returns a pointer-
            # sized HMODULE. Without an explicit ctypes restype it defaults to
            # a 32-bit c_int, truncating the module handle. Windows then rejects
            # SetWindowsHookExW with ERROR_MOD_NOT_FOUND (WinError 126).
            module = kernel32.GetModuleHandleW(None)
            if not module:
                raise ctypes.WinError(ctypes.get_last_error())

            ctypes.set_last_error(0)
            self._hook = user32.SetWindowsHookExW(
                WH_KEYBOARD_LL, self._proc, module, 0
            )
            if not self._hook:
                raise ctypes.WinError(ctypes.get_last_error())
            self.logger.info(
                "Physical key override active: %s (VK=%s)",
                self.display_name,
                self.virtual_key,
            )
        except Exception as exc:
            self._error = exc
            self._ready.set()
            return

        self._ready.set()
        msg = wintypes.MSG()
        while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) > 0:
            pass

        if self._hook:
            user32.UnhookWindowsHookEx(self._hook)
            self._hook = None
        self.logger.info(
            "Physical key override released: %s; Windows default behavior restored",
            self.display_name,
        )

    def start(self):
        self._thread = threading.Thread(
            target=self._run,
            daemon=True,
            name="whisper-physical-key-hook",
        )
        self._thread.start()
        if not self._ready.wait(3):
            raise RuntimeError("Timed out while installing the physical-key hook")
        if self._error:
            raise RuntimeError(
                f"Could not intercept {self.display_name}: {self._error}"
            )

    def stop(self):
        if self._thread_id:
            user32.PostThreadMessageW(self._thread_id, WM_QUIT, 0, 0)
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2)


def _install_physical_binding(main_module, virtual_key: int, display_name: str):
    original_setup = main_module.setup_hotkey_listener

    def setup_hotkey_listener_with_physical_key(
        hotkey_config, state_manager, voice_commands_enabled=True
    ):
        listener = original_setup(
            hotkey_config, state_manager, voice_commands_enabled
        )

        def press():
            if not listener.is_paused:
                listener._standard_hotkey_pressed()

        if listener.recording_mode == "push_to_talk":
            def release():
                if not listener.is_paused:
                    listener._push_to_talk_released()
        else:
            def release():
                if not listener.is_paused:
                    listener._arm_keys_on_release()

        hook = PhysicalKeyHook(
            virtual_key=virtual_key,
            display_name=display_name,
            on_press=press,
            on_release=release,
        )
        hook.start()

        original_stop = listener.stop_listening
        stop_lock = threading.Lock()
        stopped = False

        def stop_listening_with_restore():
            nonlocal stopped
            with stop_lock:
                if not stopped:
                    hook.stop()
                    stopped = True
            original_stop()

        listener.stop_listening = stop_listening_with_restore
        listener._physical_key_hook = hook
        return listener

    main_module.setup_hotkey_listener = setup_hotkey_listener_with_physical_key


def selftest_hook():
    """Install and immediately remove a real WH_KEYBOARD_LL hook.

    This is used by Windows CI so an import-only test cannot miss ABI/signature
    problems such as a truncated 64-bit HMODULE.
    """
    hook = PhysicalKeyHook(
        virtual_key=0x87,  # F24; do not wait for or synthesize input.
        display_name="CI hook self-test",
        on_press=None,
        on_release=None,
    )
    hook.start()
    hook.stop()
    print("physical-key hook start/stop OK")


def main():
    mode, virtual_key, display_name = _load_binding()

    import whisper_key.main as whisper_main

    if mode == "physical":
        if not virtual_key:
            raise RuntimeError(
                "Physical-key mode is configured without a valid VirtualKey"
            )
        _install_physical_binding(whisper_main, virtual_key, display_name)

    whisper_main.main()


if __name__ == "__main__":
    if "--selftest-hook" in os.sys.argv[1:]:
        selftest_hook()
    else:
        main()
