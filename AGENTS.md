# AGENTS.md

## What this is

Alpine Linux + Raspberry Pi 5 RetroArch kiosk setup. Three POSIX `sh` scripts, nothing else — no README, no CI, no tests, no package manifest. Comments are in Spanish; keep new comments in Spanish to match.

- `install.sh` — root-only: enables the edge `testing` repo (only on edge systems), `apk` packages (virtual group `retro-kiosk-deps`), emulation cores (virtual group `retro-cores`: `libretro-parallel-n64` for N64 + `libretro-snes9x` for SNES), OpenRC service enable/start, user group setup (Alpine/OpenRC, **not** systemd), `agetty` autologin on tty1, and auto-start of `start.sh` from `~/.profile`.
- `uninstall.sh` — exact inverse of `install.sh`: stops/disables the OpenRC services, restores the busybox getty in `/etc/inittab`, removes the `kiosk-retroarch` lines from `~/.profile`, drops the `edge/testing` repo line, `apk del retro-kiosk-deps retro-cores`, removes the user from the hardware groups. Deliberately keeps RetroArch config/data. Must stay in sync with `install.sh` (same package lists, same `TARGET_USER`).
- `start.sh` — session launcher: sets Wayland env, starts the PipeWire audio stack in background, then `exec cage -d -- retroarch` (Cage is the Wayland kiosk wrapper around RetroArch).

## Emulation cores (SNES + N64)

- Alpine's `retroarch` package **disables RetroArch's online updater** (`menu_show_core_updater = false` in its `config.patch`) because buildbot cores are glibc and Alpine is musl — a downloaded `.so` will not load. Cores can only come from `apk` or from source builds on the device.
- Cores are installed into `/usr/lib/libretro`, which is exactly what Alpine's patched `retroarch.cfg` points `libretro_directory` at; info files come from `libretro-core-info` (already a dependency of `retroarch`).
- Both cores live **only in the `testing` repo of `edge`** for aarch64. Stable branches (v3.22–v3.24) have no N64 core at all for aarch64 (`libretro-mupen64plus` is `arch="x86_64"`) and no `libretro-snes9x`; stable only ships `libretro-bsnes`/`libretro-beetle-bsnes`.
- `install.sh` appends `/edge/testing` to `/etc/apk/repositories` **only if an `/edge/` line already exists** — never enable edge/testing on a stable system (it mixes branches and breaks the base system). The repo line is derived from the existing mirror URL, so local mirrors keep working.
- Cores are a **separate** virtual group (`retro-cores`): if they fail to install, the base kiosk install must still succeed. Keep that separation.

## Kiosk boot flow (how it fits together)

`agetty --autologin admin` on tty1 → login runs `~/.profile` → guarded line `exec`s `start.sh` → `exec cage -d -- retroarch`. If cage/RetroArch exits, the shell dies, agetty respawns and the kiosk relaunches by itself.

Constraints that must not be broken:
- The `.profile` block is two lines both marked `kiosk-retroarch` (marker comment + guarded exec). `uninstall.sh` removes them by that marker — keep the marker on every added line.
- `install.sh` bakes the **absolute** path of `start.sh` (resolved from its own location) into `.profile`. Moving the repo breaks auto-start; re-run `install.sh` to rewrite it.
- `uninstall.sh` must restore `/etc/inittab` **before** `apk del` removes `agetty`, or tty1 is left without a getty.
- `install.sh` only rewrites `/etc/inittab` if `agetty` is actually on PATH, so a failed `apk add` cannot break console login. Keep that guard.

## Other gotchas

- `TARGET_USER` is hardcoded to `"admin"` in **both** `install.sh` and `uninstall.sh` despite the comment telling you to replace `"tu_usuario"`. Change the variable in both files, not the comment's suggestion.
- Auto-start relies on the login shell reading `~/.profile` — true for Alpine's default `ash`, not for zsh/bash-only profiles.
- `apk add --virtual retro-kiosk-deps` groups every dependency; `apk del retro-kiosk-deps` removes all of them at once.
- After install **or** uninstall, a **reboot** is required: `/etc/inittab` changes only apply when the getty respawns, and group membership (`video`, `input`, `audio`, `seat`) applies on next login. `start.sh` fails on permissions until then.
- Scripts are executable; run as `./install.sh` (root), `./uninstall.sh` (root) and `./start.sh`.

## Verifying changes

No test suite exists. At minimum run a syntax check after editing:

```sh
sh -n install.sh start.sh uninstall.sh
```

`shellcheck` is not configured in this repo; use it only if installed locally.
