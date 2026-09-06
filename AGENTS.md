# AGENTS.md

Two independent, standalone macOS bash scripts for disk cleanup. No build, tests, lint, or CI — the only validations are `bash -n <script>` syntax check and manual interactive runs.

## Scripts

- **`app-cleanup.sh`** — interactive macOS app uninstaller (bundle + caches/configs/containers/receipts/TCC). Pick an app from `/Applications` or enter a bundle ID (works for already-removed apps). Tiers: normal / advanced / complete.
- **`dev-cleanup.sh`** — interactive cache/disk manager for brew, node/npm, pip3, rustup, android, gradle, Xcode, simulators. Menu-driven per-tool; `[s]` summary, `[c]` clean-all.

Do not assume shared code or shared helpers — each is self-contained. Edits to one never affect the other.

## Shell conventions differ per file — follow each file's existing pattern

The two scripts were written differently and reflect different safety postures. Match the style of the file you're editing; do not "harmonize" them.

- **`app-cleanup.sh`** is hardened: sets `set -uo pipefail`, defines absolute paths for everything run under sudo (`RM_BIN`, `TCCUTIL_BIN`, ...), tries unprivileged removal before escalating to sudo (`remove_path`), and logs every action to a repo-relative `./Logs/appcleaner.log` (note: the log path is relative to CWD, not `$HOME`, despite a commented-out `$HOME/Library/Logs` line).
- **`dev-cleanup.sh`** is simpler: no `set` flags, bare `rm -rf` on user-owned paths, uses `$'\e...'` ANSI escapes and emoji in UI. Not covered by the hardened helpers.

Keep new code in the same posture as the surrounding script. In particular, any new `sudo`-invoked command belongs in `app-cleanup.sh`'s absolute-path idiom.

## Verification

```bash
bash -n app-cleanup.sh dev-cleanup.sh
```

Real functional testing requires an interactive terminal and a macOS user session; both scripts will prompt/loop and can't be meaningfully unit-tested. If asked to change destructive behavior, reason from the safety notes below rather than only the current code.

## Design context worth preserving

**`README.md`** is the canonical user-facing doc for the repo (the project is branded "Teardown"). It explains both scripts, how to use them, the exact paths they modify, and their safety rails — read it for intended behavior.

The safety invariants below were distilled from prior security reviews of `app-cleanup.sh`; they are deliberately not prose in README.md. Key invariants (all in `app-cleanup.sh` unless noted):

- Never delete user paths with `sudo` unless the unprivileged attempt actually failed (least privilege).
- Guard against `(null)` when resolving a bundle ID via `mdls`; every bid-keyed lookup (Caches, Containers, receipts, TCC) must skip when bid is empty — an empty `app_name` previously risked deleting a shared parent folder.
- Escape single quotes before interpolating a bundle ID into the `sqlite3` TCC query.
- Group Containers are suffix-matched and shown/confirmed separately from exact-match paths (avoids overreach like "Notion" vs "Notion Calendar").
- `mdfind` results are informational only, never auto-deleted.
- Receive `pkgutil --forget` (not raw `rm`) for receipts; `launchctl unload` before removing LaunchAgents/Daemons.
- TCC.db reads need Full Disk Access on the terminal — empty results may be a permissions issue, not absence.

Note: since these scripts delete real data on the user's machine, treat any new destructive behavior as high-stakes; runner confirms every tier and the complete tier double-warns.
