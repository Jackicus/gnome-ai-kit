---
name: new-extension
description: Start a new GNOME Shell extension in the workspace - a public GitHub repository made from the kit's skeleton, already on the shared scripts, CI, release workflow and issue forms, listed in extensions.json, with a protected main and protected tags, and seen ACTIVE in a nested shell. Use when the owner asks for a new extension.
argument-hint: "NAME | SLUG | one-sentence description"
disable-model-invocation: true
---

New extension: $ARGUMENTS

Run from a session started in the kit folder. Ask for whatever of NAME (what people read:
"Clipboard Peek"), SLUG (the UUID before `@jackicus`: `clipboard-peek`) and the one-sentence
description was not given; the repository is `Jackicus/GNOME-<NAME with hyphens>`. Making a
public repository is outward-facing: confirm the three with the owner once, then go through
to the end without stopping.

1. **Scaffold.** `.gnome-ai-kit/scripts/new-extension.sh "NAME" SLUG "DESCRIPTION"` makes
   `GNOME-<Name>/` beside the kit from `.gnome-ai-kit/template/skeleton/`: an extension that puts an icon
   in the top bar behind one setting (`show-indicator`), its preferences (an
   `Adw.SwitchRow` bound to the key), schema, `lib/app.js` (`<Class>App`, everything made
   in `enable()` and undone in `disable()`; its GObject class is `<Class>Indicator`, with
   no `GTypeName`), `./scripts/ext.conf`, a Makefile on `./scripts/kit.mk`, CLAUDE.md with the kit
   pointer, README, LICENSE (GPL-2.0-or-later); then `.gnome-ai-kit/scripts/sync.sh` over it and
   `package-lock.json`. Nothing is committed.
2. **Check it.** In the new directory: `make check` passes and `./scripts/dev.sh pack`
   ships exactly `extension.js`, `prefs.js`, `metadata.json`, the schema XML, `lib/*.js`
   and `LICENSE`.
3. **See it.** `./scripts/nested.sh start --clean --headless` reports it ACTIVE, a shot of
   the top bar shows the icon (scratch folder `<scratchpad>/<repo>/`), the log has no
   error of its own, and `stop` leaves nothing. The first `start` links the extension into
   `~/.local/share/gnome-shell/extensions/` without enabling it (`dev.sh link
   --no-enable`: the nested shell reads the same directory); enabling it in the owner's
   session, or `make install` there, is theirs to do. The setting can be tried with
   `./scripts/nested.sh run gsettings --schemadir src/schemas set
   org.gnome.shell.extensions.SLUG show-indicator false`: the icon goes.
4. **Publish.** `gh repo create Jackicus/<repo> --public --description "DESCRIPTION"
   --source . --remote origin`; the first commit ("<Name>: a top-bar icon behind one
   setting, on the kit's scripts", with the attribution lines) goes straight to `main`,
   the only direct push the repository ever takes. Then `gh repo edit` with the topics
   `gnome-shell-extension`, `gnome`, `gnome-shell`, `gjs`, and merges: squash only,
   branches deleted on merge (`allow_merge_commit=false`, `allow_rebase_merge=false`,
   `delete_branch_on_merge=true`).
5. **Protect.** Wait for the `make check` job on `main` (`gh run watch`); once it is green,
   protect `main` as every extension's is: required check `make check`, admins included,
   no force pushes or deletions (the `gh api -X PUT …/branches/main/protection` call in
   `gnome-ext:doctor`). Then `.gnome-ai-kit/scripts/protect-tags.sh Jackicus/<repo>` for the `v*` tag
   ruleset.
6. **List it.** A kit pull request adding `{"name", "repo", "alias"}` to `.gnome-ai-kit/extensions.json`
   (through the kit's loop, in a worktree of its own). From then on `pull.sh`, `sync.sh`,
   `releases.sh` and the rollout include it.
7. **Hand over.** The repository URL; that `.gnome-ai-kit/scripts/setup.sh --tools` lists anything the
   machine lacks; and the owner's own step to run it in their session: log out and back in
   (the link from step 3 is already in place), then `gnome-extensions enable SLUG@jackicus`.
   A first release is `/gnome-ext:release` when they say so.

What goes in next is ordinary work in the new repository, through its own loop: replace
the icon and the setting with what the extension is for, fill the README's sections
(`gnome-ext:readme`), and keep CLAUDE.md to what is true of it alone.
