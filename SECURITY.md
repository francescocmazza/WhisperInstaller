# Security

## What may be committed

Only installer source, patch source, generic configuration logic, CI workflows,
documentation and version pins belong in this repository.

## What must never be committed

Do not commit:

- `%APPDATA%\whisperkey\user_settings.yaml`
- logs, transcripts, debug WAVs or usage history
- GitHub/GitLab/API tokens
- private keys or certificates
- `.env` files
- Hugging Face caches or model weights
- Windows user-profile paths copied from a real machine

The repository `.gitignore` blocks the common cases. CI also runs
`scripts/check_secrets.py`.

## Supply-chain choices

- Whisper Local is pinned to a full Git commit SHA.
- Python is pinned to a specific version and its Authenticode signature is
  checked before execution.
- NVIDIA Python packages are pinned to explicit versions.
- The patcher validates exact source fragments before modifying files. If the
  installed source does not match the expected 0.18.3 layout, it aborts instead
  of guessing.

## Reporting

If a credential is ever committed, revoke/rotate it first; removing it from a
later commit is not sufficient because Git history retains it.
