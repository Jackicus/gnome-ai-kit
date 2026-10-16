---
name: port-shell-version
description: Bring a GNOME Shell extension to a new GNOME Shell version - read gnome-shell and mutter at the old and new tags, check every shell import and private reach, fix what moved with fallbacks that keep the older versions working, record what was read where, and add the version to metadata.json only once the extension has run on it. Use when a new GNOME release is out or near, when a version is asked for, or when an issue says the extension breaks on one.
argument-hint: "[the new version, e.g. 51; repository default the current one]"
---

Port to: $ARGUMENTS

A version is claimed in `shell-version` only once the extension has **run** on it.
Reading the sources says what to fix; it does not earn the claim. Library's #8
(GNOME 51: `Clutter.get_default_backend()` and `navigate_from_event` are gone) is the
shape of a typical finding.

## 1. The sources, once per machine

```bash
K=${XDG_CACHE_HOME:-$HOME/.cache}/gnome-ext-sources
for p in gnome-shell mutter; do
    [ -d $K/$p ] || git clone --filter=blob:none https://gitlab.gnome.org/GNOME/$p.git $K/$p
    git -C $K/$p fetch --tags -q
done
git -C $K/gnome-shell tag -l '51.*'      # the tags that exist
```

Read a file at a tag with `git -C $K/gnome-shell show 51.0:js/ui/panel.js`, and what
changed with `git -C $K/gnome-shell diff 50.0 51.0 -- js/ui/panel.js`. The old tag is the
newest version `shell-version` claims; for a version not yet released, the newest
`.alpha`/`.beta`/`.rc` tag or `main`, said as such.

## 2. What the extension depends on

- **The porting guide**: https://gjs.guide/extensions/upgrading/gnome-shell-<N>.html
  (WebFetch), and the guides for any versions skipped.
- **Every shell import**: `grep -rn "resource:///org/gnome/shell/" src/`, each module and
  each name taken from it, checked at the new tag.
- **Every private reach**: the repository's list (`docs/private-api.md`, or its CLAUDE.md
  section), then `grep -rnE "\._[a-zA-Z]" src/` against shell objects and anything wrapped
  with `InjectionManager` or a monkey-patch, to catch reaches the list missed.
- **Mutter, Clutter, St and GJS**: methods called on them, in mutter's `clutter/`, `src/`
  and the shell's `src/st/` at the new tag; GJS and GLib from the new platform's release
  notes.
- **Constants the extension restates** (animation times, sizes): still equal.
- The preferences: libadwaita and GTK versions the new release ships.

## 3. Fix

On a branch per version (`port/<N>`), with an issue per breakage. Each fix keeps every
version still claimed working: feature-test the new API and fall back to the old, never
branch on a version number unless there is no other way, and say in a comment which
version each path is for. `make check`. Boot the change on the versions still claimed
(the nested shell, both machines where they differ: the kit's two-machine rule).

## 4. Record what was read

`docs/compatibility.md`: which tags were read, what changed and how the extension copes,
dated. `docs/private-api.md`: every reach, with the tags it was read at and what breaks
when it moves. A repository without these files records the same in its CLAUDE.md's
private-API section.

## 5. Boot it, then claim it

Only a shell of version N running the extension earns `"N"` in `shell-version`: a
machine on that release, a VM, or a nested shell built from that version. Name where it
was booted, with `gnome-shell --version`, in `compatibility.md`. Enable, use every
feature the README promises, `stop` + `start` once, and read the logs: no errors with the
extension's prefix.

If nothing can run N yet, land the fixes, leave `shell-version` alone, and say so in the
pull request and `compatibility.md`. Never claim a future version.

## 6. Land and report

Through the loop (pull request "Fixes #N" per breakage, or one for the port with every
issue listed), then report: tags read, what broke and how each was fixed, where it was
booted, and whether the version was claimed.
