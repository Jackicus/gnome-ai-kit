---
name: releases
description: Show where every GNOME Shell extension beside the kit stands on releases - version-name on main, the last v* tag, the pull requests merged since it, main's CI, the last Release workflow run, what extensions.gnome.org carries, and the version to cut next - read-only. Use when asked what is released, what is unreleased, what version comes next, whether a release went through, or before cutting one.
argument-hint: "[names or aliases; default every extension in extensions.json] [--prs]"
---

Release state of: $ARGUMENTS (nothing given: every extension `.gnome-ai-kit/extensions.json` lists)

This reads GitHub and extensions.gnome.org and changes nothing. It is what
`gnome-ext:release` runs first.

1. Run the kit's `.gnome-ai-kit/scripts/releases.sh` with the arguments: `../.gnome-ai-kit/scripts/releases.sh` from an
   extension, `.gnome-ai-kit/scripts/releases.sh` from the kit; add `--prs` to list the unreleased pull
   requests, `--json` to work with the data. It needs `gh` signed in and the network; in a
   session with no kit beside the repository (a cloud session), run it from the copy
   `.claude/kit.sh` fetched (`~/.cache/gnome-extensions-kit/.gnome-ai-kit/scripts/releases.sh`).
2. Read the table back, one line per extension:
   - **version**: `version-name` in `src/metadata.json` on `main`.
   - **last tag**: the newest `v*` tag and its date; `none` means never released.
   - **unreleased**: pull requests merged into `main` since that tag (release pull
     requests are not counted).
   - **CI** and **release run**: the last run of the `CI` workflow on `main` and of the
     `Release` workflow; `no workflow` means the extension does not carry the kit's
     `release.yml` yet (the `rollout` skill brings it).
   - **e.g.o**: the version-name and upload number extensions.gnome.org serves for GNOME
     Shell 51, or `not published`.
   - **next**: never released, the current version-name; otherwise a minor step if any
     unreleased pull request's branch is `feat/…`, else a patch step; `-` when nothing is
     unreleased. A proposal: the owner decides.
3. Then the warnings it printed, each with what fixes it:
   - a tag without a GitHub release, or a release without its zip: re-run the Release
     workflow for that tag (Actions → Release → Run workflow, or
     `gh workflow run release.yml -R <repo> -f tag=<tag>`);
   - a failed Release run: open its URL, fix the cause in a pull request, then re-run it
     for the same tag; the tag itself is never moved;
   - version-name already tagged with work unreleased: normal between releases; the next
     release bumps it;
   - `metadata.json` sets `version`: remove it in a pull request (extensions.gnome.org
     assigns it);
   - extensions.gnome.org newer than the last tag: an upload that was not tagged; say so
     to the owner.
4. Say which extensions have something worth releasing (user-facing `feat/` or `fix/`
   work), and which have only maintenance. Releasing is `gnome-ext:release`, and only when
   the owner says so.
