# AGENTS.md

## What this is

Alpine Linux + Raspberry Pi 5 RetroArch kiosk setup. Three POSIX `sh` scripts, nothing else — no README, no CI, no tests, no package manifest. Comments are in Spanish; keep new comments in Spanish to match.

- `install.sh` — root-only: `apk` packages, OpenRC service enable/start, user group setup (Alpine/OpenRC, **not** systemd).
- `uninstall.sh` — exact inverse of `install.sh`: stops/disables the OpenRC services, `apk del retro-kiosk-deps`, removes the user from the hardware groups. Deliberately keeps RetroArch config/data. Must stay in sync with `install.sh` (same package list, same `TARGET_USER`).
- `start.sh` — session launcher: sets Wayland env, starts the PipeWire audio stack in background, then `exec cage -d -- retroarch` (Cage is the Wayland kiosk wrapper around RetroArch).

## Known defect (verified in `install.sh`)

Line 17 (`alsa-utils`) is missing its trailing `\`, so the `apk add` command ends there. Lines 18–21 parse as a stray command (`pipewire wireplumber pipewire-pulse wireplumber`), which fails because those binaries aren't installed yet — and the script has no `set -e`, so it continues silently.

Consequence: **the PipeWire packages are never installed**, while `start.sh` launches `pipewire`/`wireplumber`/`pipewire-pulse`, so audio is broken until the backslash is added. If you touch this file, fix the continuation rather than reformatting around it.

## Other gotchas

- `TARGET_USER` is hardcoded to `"admin"` in **both** `install.sh` and `uninstall.sh` despite the comment telling you to replace `"tu_usuario"`. Change the variable in both files, not the comment's suggestion.
- `apk add --virtual retro-kiosk-deps` groups every dependency; `apk del retro-kiosk-deps` removes all of them at once.
- `install.sh` ends by requiring a logout/login before group membership (`video`, `input`, `audio`, `seat`) applies — `start.sh` will fail on permissions until then.
- The header comment in `install.sh` still says `setup.sh` (stale filename).
- Scripts are executable; run as `./install.sh` (root) and `./start.sh`.

## Verifying changes

No test suite exists. At minimum run a syntax check after editing:

```sh
sh -n install.sh start.sh uninstall.sh
```

`shellcheck` is not configured in this repo; use it only if installed locally.
