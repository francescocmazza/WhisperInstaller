"""Validate the isolated runtime and optionally pre-download the model."""

from __future__ import annotations

import argparse
import importlib.metadata
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--download-model", action="store_true")
    args = parser.parse_args()

    version = importlib.metadata.version("whisper-local")
    if version != "0.18.3":
        raise RuntimeError(f"Expected whisper-local 0.18.3, found {version}")

    import ctranslate2

    compute = ctranslate2.get_supported_compute_types("cuda")
    if not compute:
        raise RuntimeError("CTranslate2 cannot use CUDA in this runtime")
    if "float16" not in compute:
        raise RuntimeError(f"CUDA works, but float16 is unavailable: {sorted(compute)}")

    print("CUDA preflight OK:", ", ".join(sorted(compute)))

    if args.download_model:
        from faster_whisper import WhisperModel
        print("Downloading/loading large-v3-turbo...")
        model = WhisperModel("large-v3-turbo", device="cuda", compute_type="float16")
        del model
        print("large-v3-turbo is ready.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
