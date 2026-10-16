#!/usr/bin/env bash
# Copies the kit's per-repository files into the extensions beside it.
#
#   .gnome-ai-kit/scripts/sync.sh [--check] [REPO...]
#
# REPO is an extension's directory name or alias from extensions.json (GNOME-Media-Controls,
# media) or a path; by default every extension extensions.json lists that is checked out
# beside the kit (scripts/pull.sh clones the rest). For each:
#
#   template/.github/workflows/ci.yml          copied
#   template/.github/workflows/release.yml     copied
#   template/.github/pull_request_template.md  copied
#   template/.github/ISSUE_TEMPLATE/*.yml      copied (bug, feature, config)
#   template/CONTRIBUTING.md                   copied
#   template/.claude/kit.sh                    copied, executable
#   template/eslint.config.mjs                 copied
#   template/scripts/dev.sh, nested.sh,        copied (the first three executable): the
#     nested_driver.py, dev-extension.js,      tooling every extension shares, which
#     kit.mk                                   reads scripts/ext.conf and the
#                                              repository's scripts/dev.d/ and nested.d/
#   template/.claude/settings.json             merged into the repository's own: the
#                                              SessionStart hook added once, the
#                                              marketplace and plugin set, everything
#                                              else kept; the SessionEnd hook that
#                                              stops the nested shell added once
#
# Two files are written by hand and only checked for: the kit pointer line in CLAUDE.md
# (template/CLAUDE.pointer.md), and scripts/ext.conf, which the shared scripts read
# (.claude/skills/rollout/nested-migration.md says what goes in it). Nothing is
# committed: each repository lands the result through its own pull request. A repository
# whose .gitignore ignores any of these files is refused, since the synced copy would never
# be committed.
#
# --check changes nothing, lists what differs, and exits 1 if anything does.

set -euo pipefail

kit=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$kit")
template=$kit/template
check=0
repos=()

for arg in "$@"; do
    case $arg in
        --check) check=1 ;;
        -h | --help) sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "sync.sh: unknown option $arg" >&2; exit 2 ;;
        *) repos+=("$arg") ;;
    esac
done

# NAME ALIAS, one extension per line.
manifest=$(python3 -c '
import json, sys
for e in json.load(open(sys.argv[1]))["extensions"]:
    print(e["name"], e["alias"])
' "$kit/extensions.json")

if [ ${#repos[@]} -eq 0 ]; then
    while read -r name _; do
        if [ -e "$root/$name/.git" ]; then
            repos+=("$root/$name")
        else
            echo "$name: not checked out beside the kit (.gnome-ai-kit/scripts/pull.sh $name clones it)"
        fi
    done <<< "$manifest"
else
    for i in "${!repos[@]}"; do
        alias_name=$(awk -v a="${repos[$i]}" '$2 == a {print $1}' <<< "$manifest")
        [ -n "$alias_name" ] && repos[i]=$alias_name
    done
fi

copies=(
    .github/workflows/ci.yml
    .github/workflows/release.yml
    .github/pull_request_template.md
    .github/ISSUE_TEMPLATE/bug.yml
    .github/ISSUE_TEMPLATE/feature.yml
    .github/ISSUE_TEMPLATE/config.yml
    CONTRIBUTING.md
    .claude/kit.sh
    eslint.config.mjs
    scripts/dev.sh
    scripts/nested.sh
    scripts/nested_driver.py
    scripts/dev-extension.js
    scripts/kit.mk
)
executables=(.claude/kit.sh scripts/dev.sh scripts/nested.sh scripts/nested_driver.py)
pointer=$(cat "$template/CLAUDE.pointer.md")
status=0

# Prints the repository's settings.json with the template merged in.
merged_settings() {
    python3 - "$1" "$template/.claude/settings.json" <<'EOF'
import json, os, sys

path, template_path = sys.argv[1], sys.argv[2]
settings = {}
if os.path.exists(path):
    with open(path) as f:
        settings = json.load(f)
with open(template_path) as f:
    template = json.load(f)

hooks = settings.setdefault('hooks', {})
for event, groups in template.get('hooks', {}).items():
    have = hooks.setdefault(event, [])
    commands = {h.get('command') for g in have for h in g.get('hooks', [])}
    for group in groups:
        if not any(h.get('command') in commands for h in group.get('hooks', [])):
            have.append(group)
for key in ('extraKnownMarketplaces', 'enabledPlugins'):
    settings.setdefault(key, {}).update(template.get(key, {}))

print(json.dumps(settings, indent=2, ensure_ascii=False))
EOF
}

for repo in "${repos[@]}"; do
    [ -d "$repo" ] || repo=$root/$repo
    if [ ! -e "$repo/.git" ]; then
        echo "sync.sh: $repo is not a git repository" >&2
        status=1
        continue
    fi
    name=$(basename "$repo")
    changed=()

    # A synced file the repository's .gitignore ignores would never be committed.
    ignored=()
    for f in "${copies[@]}" .claude/settings.json; do
        git -C "$repo" check-ignore -q --no-index "$f" && ignored+=("$f")
    done
    if [ ${#ignored[@]} -ne 0 ]; then
        echo "$name: .gitignore ignores ${ignored[*]}: un-ignore them (ignore .claude/worktrees/ or .claude/settings.local.json instead); not synced" >&2
        status=1
        continue
    fi

    for f in "${copies[@]}"; do
        if ! cmp -s "$template/$f" "$repo/$f"; then
            changed+=("$f")
            if [ $check -eq 0 ]; then
                mkdir -p "$(dirname "$repo/$f")"
                cp "$template/$f" "$repo/$f"
            fi
        fi
    done
    for f in "${executables[@]}"; do
        if [ -f "$repo/$f" ] && [ ! -x "$repo/$f" ]; then
            changed+=("$f (mode)")
            [ $check -eq 0 ] && chmod +x "$repo/$f"
        fi
    done

    want=$(merged_settings "$repo/.claude/settings.json")
    have=$(cat "$repo/.claude/settings.json" 2>/dev/null || true)
    if [ "$want" != "$have" ]; then
        changed+=(.claude/settings.json)
        if [ $check -eq 0 ]; then
            mkdir -p "$repo/.claude"
            printf '%s\n' "$want" > "$repo/.claude/settings.json"
        fi
    fi

    missing_pointer=0
    grep -qF -- "$pointer" "$repo/CLAUDE.md" 2>/dev/null || missing_pointer=1

    if [ ! -f "$repo/scripts/ext.conf" ]; then
        echo "$name: scripts/ext.conf is missing, and the shared scripts read it: write it by hand (.claude/skills/rollout/nested-migration.md)"
        [ $check -eq 1 ] && status=1
    fi
    if [ $missing_pointer -eq 1 ]; then
        echo "$name: CLAUDE.md lacks the kit pointer line (.gnome-ai-kit/template/CLAUDE.pointer.md): add it by hand"
        [ $check -eq 1 ] && status=1
    fi
    if [ ${#changed[@]} -eq 0 ]; then
        echo "$name: up to date"
    else
        [ $check -eq 1 ] && verb=differs || verb=updated
        for c in "${changed[@]}"; do
            echo "$name: $verb: $c"
        done
        [ $check -eq 1 ] && status=1
    fi
done

exit $status
