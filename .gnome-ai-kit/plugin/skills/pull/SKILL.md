---
name: pull
description: Bring gnome-ai-kit and the extensions it lists up to date - clone the ones missing, fast-forward each clean main, and say what was left alone and why (a branch, uncommitted work, unpushed or diverged commits, a merged branch whose remote is gone). Use when asked to pull, update, sync or refresh the extensions, to set up a machine, or before work that spans several of them.
argument-hint: "[all | names or aliases: ai-usage library media wallpaper]"
---

Pull: $ARGUMENTS (nothing given, or `all`: the kit and every extension)

The kit lists its extensions in `.gnome-ai-kit/extensions.json` (directory, GitHub repository, alias),
and `.gnome-ai-kit/scripts/pull.sh` does the work. Sessions already start up to date: an extension's
`.claude/kit.sh` pulls the kit and that extension, and pulls the others in the
background; a session in the kit folder pulls everything. This skill is for the rest of
the time, and for reading what was left alone.

1. Find the kit: the folder above an extension, or the session's own folder when it is
   the kit (its `.gnome-ai-kit/extensions.json` is there). With no kit beside the session (a cloud
   session, a lone clone), there is nothing to pull: say so and stop.
2. Run `<kit>/.gnome-ai-kit/scripts/pull.sh` with the names or aliases given (none for all). It
   fetches every repository, clones a missing one beside the kit, and fast-forwards only
   a `main` that is checked out and clean. It never stashes, resets, switches or deletes.
3. Read its summary back in a short table: each repository and what happened (up to
   date, pulled `old..new`, cloned, left alone, failed).
4. For each one left alone, say why and offer the fix; do it only when the user says so,
   one repository at a time:
   - **on a branch whose remote is gone** (its pull request was merged):
     `git switch main && git pull --ff-only`, then `git branch -d <branch>` (`-d`, never
     `-D`: git refuses a branch that is not merged, and then it is the user's to judge);
   - **on a branch still open**: nothing; it is work in progress. Name its pull request
     (`gh pr list --head <branch>`);
   - **uncommitted changes on main**: name the files (`git status --short`); the work
     belongs on a branch through the landing loop, never stashed or discarded unasked;
   - **unpushed commits on main**: main is protected, so they cannot be pushed; move
     them to a branch (`git switch -c <branch>`, then reset main to `origin/main` only
     with the user's OK) and land them as a pull request;
   - **diverged**: show both sides (`git log --oneline main...origin/main`) and ask;
   - **a fetch or clone failed**: usually offline or a lapsed `gh` login; say which.
5. If `.gnome-ai-kit/extensions.json` lacks an extension the user names, it is not in the kit yet:
   adding it is a kit pull request (`.gnome-ai-kit/extensions.json`, then `gnome-ext:doctor` in the
   new repository).
