# GNOME Extensions

This folder is the **kit**: shared rules, skills and templates for the GNOME Shell
extensions checked out beside it, one git repository each (`GNOME-AI-Usage`,
`GNOME-GitHub-Bar`, `GNOME-Library-Menu`, `GNOME-Media-Controls`, `GNOME-SongRec-Button`,
`GNOME-Wallpaper-FX`, `GNOME-Workspace-Scenes`, `GNOME-Workspace-Titles`). The kit is a
repository of its own (Jackicus/gnome-ai-kit) that ignores them. Its root holds only this file, `.claude/`
(the rules and the kit's own skills), `.github/` and `.gitignore`; everything else of the
kit is in `.gnome-ai-kit/`: the scripts, the template, the plugin and
`.gnome-ai-kit/extensions.json`, which lists the extensions.
`.gnome-ai-kit/scripts/pull.sh` clones and fast-forwards them, and every session starts
with the kit and its own repository pulled (`.claude/kit.sh`). A session started in an
extension loads this file and `.claude/rules/` from here, then the extension's own
CLAUDE.md, which says what that extension is and what is true only of it. When the two
disagree, the extension's file is the more specific and wins; fix whichever is wrong.

## The stack

- GJS with ES modules, GNOME Shell 50. Every `metadata.json` claims `["50"]`, the version
  each has been run on; some are audited against 48 and 49's sources and say so in their
  own CLAUDE.md. A version is claimed only once it has been booted.
- Two processes, two toolkits. `extension.js` and everything it imports run **inside the
  compositor**: St, Clutter, Meta, Shell, `resource:///org/gnome/shell/…`. `prefs.js` runs
  in the Extensions app's process: Gtk 4 and libadwaita, never St, Clutter, Meta, Shell
  or `ui/`. A module both sides import imports neither (Gio, GLib and its own pure code
  only). A shell import reached from `prefs.js` fails only when the preferences open.
- `src/` is exactly what ships: `make pack` zips it into `dist/<uuid>.shell-extension.zip`
  and `make install` copies it, both as far as `./scripts/ext.conf`'s `EXT_SHIP` says.
  `make link` installs a directory of links into `src/` whose entry point is
  `./scripts/dev-extension.js`, which stages `lib/` afresh per edit, under a directory of
  the running shell's own, so `reload` picks up edits and one shell never deletes
  another's stage.
- The tooling is the kit's, the same in every repository
  (`.gnome-ai-kit/template/scripts/`, copied by `.gnome-ai-kit/scripts/sync.sh`):
  `./scripts/dev.sh` for the extension (link, install, reload, logs, pack, check, status),
  `./scripts/nested.sh` for the nested shell, and the make targets in `./scripts/kit.mk`,
  which the Makefile includes. What is particular to an extension is `./scripts/ext.conf`
  (its UUID, name, log prefix, what ships, its checks) and its own commands and hooks in
  `./scripts/dev.d/` and `./scripts/nested.d/`; a change to the shared scripts goes to the
  kit.
- Settings are a GSettings schema in `src/schemas/`, `org.gnome.shell.extensions.<name>`.
  `glib-compile-schemas --strict` must pass: an install compiles it that way.

## Two machines

The user works on two, and a session may be on either: the main desktop (NVIDIA GTX 1080)
and an Intel HP all-in-one (Mesa). Both run GNOME Shell 50. Support is claimed per major
version ("GNOME Shell 50"), for every machine; a point release a doc mentions is fine
and is not policed. A performance measurement (frame times, CPU, GPU) says which machine
it was taken on, and an audit never "corrects" one machine's numbers to the other's.
Which one this is: `gnome-shell --version`, `lspci | grep -i vga`
or `glxinfo -B | grep renderer` (NVIDIA or Mesa Intel).

## Never the user's session

The user's desktop is the one they are working in. Everything is tried in a **nested
shell**: a second, headless GNOME Shell with its own session bus, mirrored live on the
desktop (`.claude/rules/live-session.md`; the `gnome-ext:nested-shell` skill to drive it).
Never reload, restart or enable anything in the real session to test a change, never write
the user's dconf for a test, and never touch another repository's nested shell. The nested
shell keeps settings of its own and is stopped by the repository's SessionEnd hook if the
session ends first; stop it yourself when the work is done. Shots, logs and anything
else scratch go in the repository's own folder of the scratchpad (`<scratchpad>/<repo>/`):
sessions and agents running side by side share the scratchpad, and overwrite generic names.

## Style

- `make lint` is ESLint with gjs.guide's configuration (`eslint.config.mjs`, the same in
  every repo: `.gnome-ai-kit/template/eslint.config.mjs`). No errors, and no new warnings.
- 4-space indents, `const` and `let`, `console.*` for logging behind the extension's own
  `[Name]` prefix, which `make logs` filters on (`make logs SINCE='5 min ago'` for a
  window). The shipped code logs failures only.
- Comments describe the code as it is: no phase numbers, review IDs, plans or history.
  History is git's.
- Only the code that is needed, and comments only for the why
  (`.claude/rules/simplicity.md`): extensions.gnome.org rejects code that reads as
  generated. `make check` ends with `./scripts/dev.sh size`: the lines, comment share and
  `try` count of `src/`.
- GObject type names, CSS classes, settings paths, cache and runtime directories are
  global to the shell: each extension prefixes its own (`.claude/rules/gjs-st.md`).
- Private shell API (an underscore field, an unexported class) is listed where the repo
  keeps that list (`docs/private-api.md` or its CLAUDE.md), with what breaks when it moves.

## Landing a change

`main` is protected on every extension and on the kit: no direct push, from anyone. The
required check is the `make check` job in `.github/workflows/ci.yml`.

1. **An issue first**, for anything but a trivial fix (a typo, a comment). Separate
   problems are separate issues and separate pull requests.
2. **A branch per issue**, named for it (`fix/…`, `feat/…`, `docs/…`).
3. **`make check`** passes on the branch: ESLint, plus whatever the repo checks without a
   shell (schemas, imports, parsers, shaders). A visible change is also seen in the nested
   shell, before and after, and an enable-path change survives a nested `stop` + `start`.
4. **Push, open the pull request** with "Fixes #N" and how it was verified
   (`.github/pull_request_template.md`).
5. **Wait for CI to go green**, fix what it finds, then
   `gh pr merge --squash --delete-branch`. No approving review is required, so a session
   merges its own.
6. **Check main's CI run** after the merge, and pull main locally.

"Fix this" or "implement this" authorises the whole loop: carry it through to the merge
without stopping to ask. Ask first only for what reaches outside the repo and the nested
shell: the user's real session or settings, a real launch, an online scan with real keys,
a release (`gnome-ext:release`).

A change that makes a line in a CLAUDE.md, a `.claude/rules/` file, a skill or `docs/`
wrong fixes that line in the same pull request. A rule that turns out to be true of every
extension moves here, in a kit pull request, and leaves the extensions' files.

## Where an extension keeps its own

- `CLAUDE.md`, at most 200 lines: what the extension is, its layout, how its parts fit,
  its design rules and the traps that are its alone. It starts with the kit pointer line
  (`.gnome-ai-kit/template/CLAUDE.pointer.md`).
- `.claude/rules/<area>.md` with `paths:` frontmatter, for an area's detail that only
  matters while its files are open (the scanner, the shaders, a VLC socket).
- `.claude/skills/drive-extension/SKILL.md`: what this extension looks like in the nested
  shell (coordinates, its own commands and fixtures, what must never be pressed). The
  generic driving is the kit's `gnome-ext:nested-shell` skill; the drive skill does not
  repeat it.
- `.claude/commands/` (`/logs`, `/reload`, `/status`, `/preview`, …): per repo, since each
  names its own log line, its own healthy state and its own data.
- `.claude/settings.json`: the kit's SessionStart and SessionEnd hooks and plugin, merged
  in by `.gnome-ai-kit/scripts/sync.sh`.
- `./scripts/ext.conf`, `./scripts/dev.d/`, `./scripts/nested.d/` and the Makefile's own
  targets after `include scripts/kit.mk`.

## Skills from the kit

The `gnome-ext` plugin (`.gnome-ai-kit/plugin/`, its marketplace
`.gnome-ai-kit/.claude-plugin/`) is enabled in each extension's settings and installed once
per machine by `.gnome-ai-kit/scripts/setup.sh`: `gnome-ext:fix-bug`, `gnome-ext:review-pass`,
`gnome-ext:nested-shell`, `gnome-ext:release`, `gnome-ext:doctor`,
`gnome-ext:screenshots` (published shots, stand-in data only), `gnome-ext:ego-review`
(the extensions.gnome.org review, before any upload), `gnome-ext:port-shell-version`,
`gnome-ext:hig-polish`, `gnome-ext:readme` (the README skeleton and the GitHub page),
`gnome-ext:pull` (the kit and the extensions up to date, and why one was left alone),
`gnome-ext:releases` (what each has released, and what is waiting),
`gnome-ext:simplify-pass` (code down to the simplicity rule, behaviour proven unchanged).
A release is a pushed `v*` tag: each extension's `Release` workflow builds the zip and the
GitHub release, whose notes are the changelog. Release tags are protected and never move.
Outside this workspace (a cloud session, a fresh clone) the plugin is not there;
`.claude/kit.sh` prints this file and the rules into the session and says where the
skills are on disk, to be read as playbooks.

## Working on the kit

The kit goes through the same loop: issue, branch, `.gnome-ai-kit/scripts/check.sh` (what
the kit's CI runs), pull request, green CI, squash merge. The kit folder is one checkout every session
shares, so a kit branch lives in a worktree of its own (`git worktree add`), never by
switching the folder's branch. Then:

- after a change under `.gnome-ai-kit/template/` or `.gnome-ai-kit/scripts/sync.sh`, once
  it is merged, the kit's own `rollout` skill (`.claude/skills/rollout/`, loaded only in a
  session started here) lands it in each extension through its own pull request;
  `.gnome-ai-kit/scripts/sync.sh --check` lists what differs;
- a new extension starts with the kit's own `new-extension` skill
  (`.gnome-ai-kit/scripts/new-extension.sh` over `.gnome-ai-kit/template/skeleton/`), never
  by copying a sibling;
- after a change under `.gnome-ai-kit/plugin/`, nothing: the plugin is read from this
  folder, so the next session sees it. Bump `.gnome-ai-kit/plugin/.claude-plugin/plugin.json`'s
  version when a skill's meaning changes.

`.gnome-ai-kit/scripts/check.sh` checks that every backticked path in this file, the rules
and the skills that starts `.gnome-ai-kit/`, `.claude/rules/` or `.github/` exists in the
kit (a `.github/` path in `.gnome-ai-kit/template/` counts). An extension's
own scripts are therefore written `./scripts/…`.
