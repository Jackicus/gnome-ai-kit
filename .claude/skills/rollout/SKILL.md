---
name: rollout
description: Land a merged kit change to .gnome-ai-kit/template/ or .gnome-ai-kit/scripts/sync.sh in every extension beside the kit - sync.sh into each, review, make check, then each extension's own issue, branch, pull request, green CI and squash merge - until sync.sh --check is clean for all. Use after a kit pull request that changes what the extensions carry has been merged.
argument-hint: "[extension names or aliases; default every extension in extensions.json]"
---

Roll out to: $ARGUMENTS (nothing given: every extension `.gnome-ai-kit/extensions.json` lists)

This runs in a session started in the kit folder; it is the kit's own skill, not the
plugin's. The extensions' `main` is protected, so a template change reaches them only as
one pull request each, through the loop their CLAUDE.md describes.

## Before

- The kit change is **merged**, and the kit checkout is on `main`, pulled. Never roll out
  from a branch: the extensions would carry files that `main` does not have.
- `.gnome-ai-kit/scripts/sync.sh --check` lists what differs per extension. An extension already up to
  date needs nothing. One that `sync.sh` refuses (its `.gitignore` ignores a synced file)
  gets that fixed in the same pull request.
- `.gnome-ai-kit/scripts/pull.sh` brings every extension's checkout up to date (and clones a missing
  one). One it leaves alone (work in progress, another session's branch, uncommitted
  changes) is not rolled out to: name it in the report.

## Each extension

1. `gh issue create`: "Carry the kit's <what changed>", linking the kit pull request.
2. A branch `chore/kit-sync-<short-name>` from a fresh `main`.
3. `.gnome-ai-kit/scripts/sync.sh <extension>` from the kit. Read the whole diff
   (`git -C <extension> diff`, and `git -C <extension> status` for new files): only the
   synced files change, and each change is the kit's. A file the extension had changed
   by hand is a finding for the report, not something to keep or drop silently.
4. Whatever the change needs that `sync.sh` cannot do: a new package in
   `./.github/ci-packages`, a line in the extension's CLAUDE.md that the template now
   contradicts. An extension without `./scripts/ext.conf` is moving onto the shared
   scripts for the first time: `nested-migration.md`, beside this skill, says what moves
   where and how to verify it. Nothing else goes in: a rollout pull request never carries
   other work.
5. `make check` in the extension.
6. Commit (subject says what is now true: "CI caches the npm modules, as the kit's
   template does now"), push, open the pull request with "Fixes #N" and a link to the kit
   pull request, wait for the `make check` job to go green, then
   `gh pr merge --squash --delete-branch`, check `main`'s run and pull `main`.

With more than two extensions, give each one to a subagent with these steps and the kit
pull request's link; they touch separate repositories, so they run in parallel. Two
agents never work in the same extension at once, and each keeps its scratch files in its
repository's folder of the scratchpad (`<scratchpad>/<repo>/`). The kit itself is one
checkout that every session shares: a kit branch is made in a worktree of its own
(`git worktree add`), never by switching the kit folder's branch.

## After

- `.gnome-ai-kit/scripts/sync.sh --check` is clean for every extension (`up to date` each).
- When the rollout brought `.github/workflows/release.yml` to an extension for the first
  time, run `.gnome-ai-kit/scripts/protect-tags.sh <extension>` once its pull request has merged, so its
  release tags can never be moved or deleted; `.gnome-ai-kit/scripts/releases.sh` then shows its
  `release run` as `never run` rather than `no workflow`.
- Report: the kit pull request, one line per extension (its pull request and CI, or why it
  was skipped), and anything an extension had changed by hand in a synced file.
