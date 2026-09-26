# Third-party notices

This repository is an installer/configuration wrapper. It does **not** vendor
Whisper model weights, CUDA binaries, Python, or the full Whisper Local source.

## Whisper Local

- Project: `drajb/whisper-local`
- Pinned version: `0.18.3`
- Pinned commit: `8e05b840fac737d4e0dec0886c6d38d0664f94c8`
- License: MIT
- Source: https://github.com/drajb/whisper-local

The installer downloads that exact Git commit at installation time and applies
the local continuity patch in `patches/apply_seamless_patch.py`.

## Python

The installer uses the official Python Software Foundation Windows installer,
pinned to Python 3.12.10, and verifies its Windows Authenticode signature before
running it.

## NVIDIA runtime packages

- `nvidia-cuda-runtime-cu12==12.9.79`
- `nvidia-cublas-cu12==12.9.1.4`
- `nvidia-cudnn-cu12==9.10.2.21`

These packages are downloaded from PyPI at install time and are not
redistributed by this repository.

## Whisper model

`large-v3-turbo` is downloaded by `faster-whisper` / Hugging Face at install
time unless model pre-download is skipped. Model files are never committed.
