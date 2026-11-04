"""Validate the isolated runtime and optionally pre-download the selected model."""

from __future__ import annotations

import argparse
import importlib.metadata


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--download-model", action="store_true")
    parser.add_argument("--device", choices=("cuda", "cpu"), required=True)
    parser.add_argument("--compute-type", choices=("float16", "int8"), required=True)
    parser.add_argument(
        "--model",
        choices=("large-v3-turbo", "medium", "small"),
        required=True,
    )
    args = parser.parse_args()

    version = importlib.metadata.version("whisper-local")
    if version != "0.18.3":
        raise RuntimeError(f"Expected whisper-local 0.18.3, found {version}")

    import ctranslate2

    compute = ctranslate2.get_supported_compute_types(args.device)
    if not compute:
        raise RuntimeError(
            f"CTranslate2 cannot use device={args.device!r} in this runtime"
        )
    if args.compute_type not in compute:
        raise RuntimeError(
            f"{args.device} works, but {args.compute_type} is unavailable: "
            f"{sorted(compute)}"
        )

    print(
        f"{args.device.upper()} preflight OK: "
        + ", ".join(sorted(compute))
    )

    if args.download_model:
        from faster_whisper import WhisperModel

        print(
            f"Downloading/loading {args.model} "
            f"on {args.device}/{args.compute_type}..."
        )
        model = WhisperModel(
            args.model,
            device=args.device,
            compute_type=args.compute_type,
        )
        del model
        print(f"{args.model} is ready.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
