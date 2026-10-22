# GNOME Extensions kit

Shared Claude Code rules, skills and templates for Jackicus's GNOME Shell extensions. Each
extension is a git repository of its own, checked out **inside** this folder; the kit
ignores them (`.gitignore`) and holds only what they share, so a rule is written once and
cannot drift between five copies.

```
gnome-ai-kit/                      this repository: Jackicus/gnome-ai-kit
├── CLAUDE.md                      rules for every extension session (loaded automatically)
├── .claude/rules/                 the same, by topic: live-session.md, gjs-st.md,
│                                  simplicity.md
├── .claude/skills/rollout/        the kit's own skill: land a template change everywhere
├── .claude/skills/new-extension/  the kit's own skill: start a new extension
├── .github/workflows/ci.yml       the kit's CI (runs check.sh)
├── .gnome-ai-kit/                 everything else of the kit:
│   ├── README.md                  this file
│   ├── extensions.json            the extensions: directory, GitHub repository, alias
│   ├── .claude-plugin/marketplace.json
│   ├── plugin/                    the gnome-ext plugin: fix-bug, review-pass,
│   │                              nested-shell, release, doctor, screenshots,
│   │                              ego-review, port-shell-version, hig-polish, readme,
│   │                              pull, releases, simplify-pass
│   ├── template/                  files every extension carries (CI, the release
│   │                              workflow, the kit hook, ESLint, the pull request
│   │                              template, the issue forms, CONTRIBUTING.md, settings
│   │                              to merge, and scripts/: dev.sh, nested.sh,
│   │                              nested_driver.py, dev-extension.js, kit.mk;
│   │                              skeleton/, a new extension's starting point)
│   └── scripts/
│       ├── pull.sh                the kit and the extensions up to date (clones what is missing)
│       ├── setup.sh               once per machine: install the plugin, list missing tools
│       ├── sync.sh                copy template/ into the extensions
│       ├── releases.sh            every extension's release state, read-only
│       ├── protect-tags.sh        make an extension's v* tags permanent
│       ├── new-extension.sh       scaffold a new extension from template/skeleton/
│       └── check.sh               the kit's own check (CI runs it)
├── GNOME-AI-Usage/                an extension, its own repository (ignored here)
├── GNOME-GitHub-Bar/             …
├── GNOME-Library-Menu/
├── GNOME-Media-Controls/
├── GNOME-SongRec-Button/
├── GNOME-Wallpaper-FX/
├── GNOME-Workspace-Scenes/
└── GNOME-Workspace-Titles/
```

## How a session gets the kit

Claude Code reads every `CLAUDE.md` from the working directory up to `/`, and the
`.claude/rules/` beside them, so a session started in `GNOME-Media-Controls/` loads this
folder's `CLAUDE.md` and rules first and the extension's own after them. Skills in a
parent folder are not loaded that way, which is why they ship as a plugin: each
extension's `.claude/settings.json` declares `.gnome-ai-kit/` as a plugin marketplace
(`"path": "../.gnome-ai-kit"`) and enables `gnome-ext` there. The plugin is read from the
kit's folder, so a `git pull` here is all an update takes.

Each extension's SessionStart hook, `.claude/kit.sh`:

- **beside the kit**: pulls it (`--ff-only`, 15 s at most) when it is on `main`, and if
  that brought anything new, says so and tells the session to re-read the rules, which
  were loaded before the pull; fast-forwards the extension itself when it is on a clean
  `main` (or says in one line why it left it); then starts `.gnome-ai-kit/scripts/pull.sh` for the
  other extensions in the background, and reports what the previous background pull
  found;
- **without a kit beside it** (a cloud session, a fresh clone elsewhere): clones the kit
  into `~/.cache/gnome-extensions-kit` (or updates it) and prints its `CLAUDE.md` and
  rules into the session, with the path of the skills to read as playbooks;
- offline, it says in one line what it could not do. It never fails the session.

A session started in this folder runs `.gnome-ai-kit/scripts/pull.sh --quiet` itself (the kit's own
`.claude/settings.json`), so kit work starts with every extension current.

Every extension's own `CLAUDE.md` opens with one line saying where the shared rules come
from (`.gnome-ai-kit/template/CLAUDE.pointer.md`).

## A new machine

```bash
git clone https://github.com/Jackicus/gnome-ai-kit.git && cd gnome-ai-kit && .gnome-ai-kit/scripts/pull.sh && .gnome-ai-kit/scripts/setup.sh
```

`pull.sh` clones every extension `.gnome-ai-kit/extensions.json` lists beside the kit.

`setup.sh` registers `.gnome-ai-kit/` as the `gnome-extensions` marketplace (again, if it
was registered from another folder), installs `gnome-ext`, and leaves it off at user level, so it is on in the extensions (their
settings enable it) and nowhere else. Run it again any time; it changes nothing the
second time. It ends by listing the tools the extensions' scripts use that the machine
lacks (shared ones in `setup.sh`, each extension's in its `scripts/ext.conf` `EXT_TOOLS`),
with one `pacman` command; it installs nothing. `.gnome-ai-kit/scripts/setup.sh --tools` runs only that.

## Keeping up to date

`.gnome-ai-kit/scripts/pull.sh` pulls the kit, then every extension in parallel (or those named, by
directory or alias: `.gnome-ai-kit/scripts/pull.sh library media`). A missing one is cloned; one on a
clean `main` is fast-forwarded; anything else (another branch, uncommitted changes,
unpushed or diverged commits on `main`) is fetched and left alone, with the reason in its
summary line. A local branch whose remote is gone, because its pull request was merged,
is named, never deleted. `--quiet` prints only what changed and what was left. The
`gnome-ext:pull` skill runs it from any session and offers the fix for each repository it
left alone.

## Releases

A release is a pushed tag. In an extension, `git tag -a v1.1 -m "Name 1.1"` on the merged
`main` and `git push origin v1.1`: its `Release` workflow (`.gnome-ai-kit/template/.github/workflows/release.yml`)
checks the tag against `version-name` in `src/metadata.json`, runs `make check`, packs the
zip with `./scripts/dev.sh pack`, and publishes the GitHub release with the zip and notes
listing the pull requests merged since the last release (`feat/` as Added, `fix/` as
Fixed). A tag with a suffix (`v1.1-beta.1`) is a prerelease. The GitHub releases are the
changelog. Uploading the zip to extensions.gnome.org is the owner's.

Tags are permanent: `.gnome-ai-kit/scripts/protect-tags.sh` gives each extension a ruleset that refuses
moving or deleting a `v*` tag, for everyone. A wrong release is followed by the next
version, never retagged. `.gnome-ai-kit/scripts/releases.sh` (the `gnome-ext:releases` skill) shows every
extension's version, last tag, unreleased pull requests, CI, last release run and
extensions.gnome.org version, and proposes the next version; `gnome-ext:release` cuts one,
only when the owner says so.

## Changing the kit

The kit takes changes the way the extensions do: an issue, a branch, `.gnome-ai-kit/scripts/check.sh`,
a pull request, a green `kit check`, a squash merge. Then:

- **`CLAUDE.md`, `.claude/rules/`, `.gnome-ai-kit/plugin/`**: nothing more. The next session in any
  extension sees it.
- **`.gnome-ai-kit/template/`**: `.gnome-ai-kit/scripts/sync.sh` copies it into every extension (or name some:
  `.gnome-ai-kit/scripts/sync.sh GNOME-Media-Controls`), merging `.claude/settings.json` rather than
  replacing it; each extension lands the result through its own pull request.
  `.gnome-ai-kit/scripts/sync.sh --check` changes nothing and lists what differs. In a Claude Code
  session started in this folder, the `rollout` skill does all of that.

## A new extension

In a Claude Code session started in this folder, `/new-extension NAME | SLUG |
description` does it all (`.claude/skills/new-extension/`). By hand:

1. `.gnome-ai-kit/scripts/new-extension.sh "Clipboard Peek" clipboard-peek "One sentence."` makes
   `GNOME-Clipboard-Peek/` beside the kit from `.gnome-ai-kit/template/skeleton/`: a working extension
   (a top-bar icon behind one setting, its preferences and schema, `lib/app.js` as
   every extension has it, `scripts/ext.conf`, a Makefile on
   `scripts/kit.mk`, CLAUDE.md with the pointer line, README, LICENSE), synced, with
   `package-lock.json`, in a fresh git repository with nothing committed.
2. `make check`, then see it ACTIVE in `./scripts/nested.sh start --clean --headless`.
3. `gh repo create Jackicus/GNOME-Clipboard-Peek --public --source . --push` with the
   first commit (the only direct push it takes), topics, squash-only merges.
4. Once CI is green on `main`: protect `main` (required check `make check`, as
   `gnome-ext:doctor` sets it) and run `.gnome-ai-kit/scripts/protect-tags.sh Jackicus/GNOME-Clipboard-Peek`.
5. Add it to `.gnome-ai-kit/extensions.json` in a kit pull request.

## The development scripts

Every extension runs the same `./scripts/dev.sh` (link, install, reload, logs, pack,
check, status), `./scripts/nested.sh` (the nested shell), `./scripts/nested_driver.py`,
`./scripts/dev-extension.js` and the make targets in `./scripts/kit.mk`, copied from
`.gnome-ai-kit/template/scripts/` by `.gnome-ai-kit/scripts/sync.sh`; a fix to them is made once, here. What differs
is the extension's own: `scripts/ext.conf` (its UUID, name, log prefix, what ships, its
checks) and the commands and hooks in `scripts/dev.d/` and `scripts/nested.d/` (a VLC
player, a virtual pad, a demo library, stand-in logins). Moving an extension onto them for
the first time is `.claude/skills/rollout/nested-migration.md`.

The nested shell's settings are its own (the keyfile backend in a directory of its own
under `~/.local/state/gnome-extensions-nested/`), so it never writes the user's dconf;
`start --stand-in` runs it over stand-in data, for the screenshots that are published:
a scratch `HOME`, the system's `PATH`, and without the variables `scripts/ext.conf`'s
`EXT_STAND_IN_UNSET` names (any that would point the extension at real data).
