# Moving an extension onto the kit's shared scripts

The first rollout of `.gnome-ai-kit/template/scripts/` replaces an extension's own `./scripts/dev.sh`,
`./scripts/nested.sh`, `./scripts/nested_driver.py` and `./scripts/dev-extension.js`, and
adds `./scripts/kit.mk`. What was particular to the extension moves into files of its own,
which the shared scripts read. One pull request per extension, through the rollout skill's
steps; this is step 4 for that rollout.

## What the extension keeps

- **`./scripts/ext.conf`** (bash, sourced; written by hand, never synced):

  ```bash
  # What the kit's shared scripts (dev.sh, nested.sh, dev-extension.js, kit.mk)
  # need to know about this extension. Sourced by bash.
  EXT_UUID=media-controls@jackicus
  EXT_NAME='Media Controls'
  # The prefix every log line carries, and the class lib/app.js exports.
  EXT_LOG_PREFIX='[Media Controls]'
  EXT_APP_CLASS=MediaControlsApp
  # What ships besides the entry points, metadata, stylesheet and schema: DIR:PATTERN under src/.
  EXT_SHIP=("lib:*.js")
  # dev.sh commands 'dev.sh check' (and so 'make check') runs after the schema.
  EXT_CHECKS=()
  # Helpers 'nested.sh stop' sweeps if they outlive the session.
  NESTED_STRAYS=("$REPO_DIR/scripts/fakepad.py")
  # Stand-in commands overlaid on /usr/bin under 'start --stand-in'.
  EXT_STAND_IN_BINS=()
  # Variables removed from the environment under 'start --stand-in', so none points the
  # extension at real data (a provider's config directory, say).
  EXT_STAND_IN_UNSET=()
  # Development tools this extension's scripts use beyond the kit's, CHECK|PACKAGE|WHAT FOR
  # (CHECK is cmd:NAME or py:MODULE); the kit's '.gnome-ai-kit/scripts/setup.sh --tools' lists the missing.
  EXT_TOOLS=("cmd:vlc|vlc|player" "cmd:ffmpeg|ffmpeg|the test video" "py:evdev|python-evdev|fakepad.py")
  ```

  `EXT_SLUG` defaults to the UUID before `@` (run directory, Wayland display, staging
  directory). `EXT_SHIP` must reproduce exactly what the old `pack` shipped: compare
  `unzip -Z1` of the old and new zips; they list the same files.
- **`./scripts/dev.d/<name>.sh`**: the extension's own `dev.sh` commands, as `cmd_<name>`
  functions (`dev.sh foo-bar` runs `cmd_foo_bar`), and the `dev_status` hook for extra
  `status` lines. Starts with a header whose command lines read
  `#   ./scripts/dev.sh NAME ...`, which `help` prints. A `cmd_` named like a shared one
  replaces it.
- **`./scripts/nested.d/<name>.sh`**: the same for `nested.sh`, plus the hooks
  `nested_stand_in HOME STAGE` (put stand-in data in HOME, once per start),
  `nested_stand_in_stage STAGE` (adjust the staged copy of `src/`, e.g. swap a module;
  runs at every stage, `reload` included), `nested_started`, `nested_stopping`,
  `nested_status`.
  Inside, the shared functions are there to call: `nested_env`, `config_dir`, `cmd_start`,
  `cmd_do`, `require_running`, `info`/`ok`/`warn`/`die`, `$RUN_DIR`, `$REPO_DIR`.
- **The Makefile**: `include scripts/kit.mk`, then only the extension's own targets.
  `kit.mk` has link, install, reload, logs, pack, schema, check, lint, uninstall, status,
  clean, help and the nested targets; `make` alone prints help (it used to install).

Take the moved functions from the old scripts (`git show main:scripts/dev.sh`), not from
memory, and keep their comments.

## Per extension

- **Media Controls** (worked through when the kit's scripts were written): `dev.d`:
  `devices`, `stalls`, `dev_status` (libmanette). `nested.d`: `player`, `mpris`, `pad`,
  and its own `preview`. The old `setup_config_home` goes: the nested session's own
  `XDG_CONFIG_HOME` is now private, so `player` uses `"$(config_dir)"` for VLC's settings
  and keeps its data under `$RUN_DIR/vlc/data`. `NESTED_STRAYS`: `fakepad.py`. Rewrite
  `.claude/rules/nested-shell.md` to what is still its own (VLC's socket, the headless
  VLC flags, the X11 cookie is now the kit's).
- **Games Library** and **Video Library**: `EXT_SHIP` adds `backend:*.py` (Games) or
  `backend:*.js` (Video) and `icons:*.svg`; `EXT_CHECKS=(scanner)`, with the old
  `cmd_check` minus its schema step as `cmd_scanner` in `dev.d` (scratch `HOME`, offline).
  `dev.d` also: `scan`, `stalls`, (Video) `prune`, `dev_status` (cache and library lines).
  `nested.d`: `nested_stand_in() { python3 "$REPO_DIR/scripts/demo_library.py" "$1/.cache"; }`
  (it wrote the library under `XDG_CACHE_HOME` before; check the path it writes), so
  `start --stand-in` (or the old `--demo`) shows the invented library. The settings and
  library lines the old `status` printed are the shared `settings:`/`data:` lines now.
- **Wallpaper FX**: `EXT_LOG_PREFIX='[WallpaperFx]'`; `EXT_CHECKS=(shaders)` with
  `cmd_shaders` running `node scripts/shaders.mjs check`; `dev.d`: `prefs` (the user's
  own session). Makefile keeps `bench` and a `zip: pack` alias. `--monitors N` is shared
  now. Fixes GNOME-Wallpaper-FX#9: each shell stages under a directory of its own.
- **AI Usage**: `EXT_SHIP=("lib:*.js" "icons:*.svg")`, `EXT_CHECKS=(imports assets
  parsers)` (each a `dev.d` command, as before; the old `schemas` command is the shared
  `schema`), `EXT_STAND_IN_BINS=(claude codex agy)`,
  `EXT_STAND_IN_UNSET=(CODEX_HOME)`, `providers` in `dev.d` (real logins and the
  network: the user's to run). Its nested shell becomes the shared long-lived one
  (`./scripts/nested.sh start|stop`; `dev.sh nested [--window|--keep]` goes). `nested.d`:
  `nested_stand_in` writes the stand-in logins and `nested_stand_in_stage` copies
  `scripts/stand-in-http.js` over `"$1/lib/http.js"`; `cmd_shots [--light]` is the old `take_shots` over
  `start --stand-in --headless` (light: `run gsettings set org.gnome.desktop.interface
  color-scheme prefer-light`), then `stop`. The SessionEnd hook arrives with the sync.
  Re-measure the click coordinates if the shots move.

## Also in the same pull request

- `lib/`: no class sets a `GTypeName` (a set one fails to register again after an edit
  and a reload; GJS's own name follows the stage's path), and no per-load name helper;
  the JS class name carries the prefix (Media Controls #48, Wallpaper FX #39).
- Every doc that names an old command or flag: CLAUDE.md, `.claude/rules/`, the
  drive-extension skill, `.claude/commands/`, README's development section.
  `make logs '…'` is `make logs SINCE='…'`; a plain nested `start` no longer shares the
  real settings, so warnings about that go.
- `.github/ci-packages` still names what `make check` needs.

## Verify, before the pull request

Record `md5sum ~/.config/dconf/user` first. Then, headless:

1. `make check`; `./scripts/dev.sh pack` (same file list as before); `make help` lists
   the extension's own commands once each.
2. `./scripts/nested.sh start --clean --headless` → ACTIVE; `status` says its settings are
   its own; `run timeout 5 gsettings --schemadir src/schemas set …` changes the nested
   value and not the real one.
3. `start --stand-in --headless` (after a `stop`) → ACTIVE, logs
   `Enabled from $XDG_RUNTIME_DIR/<slug>/shell-<pid>/lib-…`; edit a file under `src/lib/`
   (then undo it), `reload` → ACTIVE, a new `lib-…` stage, no "already registered" in
   `logs 400 --all`; the real session's own stage beside it is untouched (Wallpaper FX:
   list `$XDG_RUNTIME_DIR/wallpaper-fx/` before and after).
4. A `shot` of what the extension draws, looked at.
5. `stop`: "nothing of its session is left running"; no `$XDG_RUNTIME_DIR/<slug>-nested`,
   no `<slug>-dev` socket or lock, no `/tmp/.X*-lock` holding the stopped shell's pid.
6. The dconf checksum is unchanged.

Once, on this machine, delete what the old scripts' nested settings left:
`~/.config/dconf/<slug_with_underscores>_nested` and
`$XDG_RUNTIME_DIR/dconf/<same>` (never `user`).

## After the merge: the user's

The real session still runs the old development entry point until the link is remade and
the session restarted: say so in the report, never do it. `make link` (writes
`dev-extension.json` beside the link; `make status` flags a link without it), then a log
out and back in.
