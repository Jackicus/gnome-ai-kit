#!/usr/bin/env bash
# Brings the kit and the extensions it lists in extensions.json up to date.
#
#   .gnome-ai-kit/scripts/pull.sh [--quiet] [--no-kit] [--skip NAME] [NAME|ALIAS...]
#
# The kit first, then every extension (or those named, by directory name or alias:
# ai-usage, library, media, wallpaper), in parallel:
#
#   missing                      cloned beside the kit
#   on a clean main              fetched and fast-forwarded
#   anything else                fetched and left alone: another branch, uncommitted
#                                changes, unpushed or diverged commits on main
#
# A local branch whose remote branch is gone (its pull request was merged) is named, not
# deleted. Nothing is ever discarded, stashed, reset or switched. One line per repository
# at the end; --quiet prints only what changed and what was left alone. --no-kit skips the
# kit itself, --skip leaves one extension out (both for .claude/kit.sh). Exits 1 when a
# clone or fetch failed.

set -uo pipefail

kit=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$kit")
quiet=0
pull_kit=1
skip=
wanted=()

while [ $# -gt 0 ]; do
    case $1 in
        --quiet) quiet=1 ;;
        --no-kit) pull_kit=0 ;;
        --skip) skip=${2:-}; shift ;;
        -h | --help) sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "pull.sh: unknown option $1" >&2; exit 2 ;;
        all) ;;
        *) wanted+=("$1") ;;
    esac
    shift
done

# NAME REPO ALIAS, one extension per line.
if ! manifest=$(python3 -c '
import json, sys
for e in json.load(open(sys.argv[1]))["extensions"]:
    print(e["name"], e["repo"], e["alias"])
' "$kit/extensions.json"); then
    echo "pull.sh: cannot read $kit/extensions.json" >&2
    exit 2
fi

names=()
repos=()
while read -r name repo alias; do
    take=0
    if [ ${#wanted[@]} -eq 0 ]; then
        take=1
    else
        for w in "${wanted[@]}"; do
            [ "$w" = "$name" ] || [ "$w" = "$alias" ] && take=1
        done
    fi
    [ "$name" = "$skip" ] && take=0
    if [ $take -eq 1 ]; then
        names+=("$name")
        repos+=("$repo")
    fi
done <<< "$manifest"

for w in "${wanted[@]}"; do
    if ! grep -qE "(^| )$w( |$)" <<< "$manifest"; then
        echo "pull.sh: $w is not in extensions.json (names and aliases: $(awk '{printf "%s%s", sep, $3; sep=", "}' <<< "$manifest"))" >&2
        exit 2
    fi
done

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

# Writes "STATE<TAB>message" to $out/LABEL; STATE is ok (unchanged), changed, alone or failed.
update() {
    local dir=$1 label=$2 repo=$3
    local result=$out/$label
    if [ ! -e "$dir/.git" ]; then
        if [ -z "$repo" ]; then
            printf 'failed\tnot a git checkout\n' > "$result"
        elif err=$(timeout 120 git clone -q "https://github.com/$repo.git" "$dir" 2>&1); then
            printf 'changed\tcloned from %s\n' "$repo" > "$result"
        else
            printf 'failed\tclone of %s failed: %s\n' "$repo" "${err%%$'\n'*}" > "$result"
        fi
        return
    fi

    local note=
    if ! err=$(timeout 30 git -C "$dir" fetch -q --prune origin 2>&1); then
        note="; fetch failed (${err%%$'\n'*}), so this is as last fetched"
    fi

    local gone
    gone=$(git -C "$dir" for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
        | awk '$2 == "[gone]" {printf "%s%s", sep, $1; sep=", "}')
    [ -n "$gone" ] && note="$note; remote branch gone (merged?): $gone"

    local branch dirty ahead behind
    branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD) || branch=
    dirty=$(git -C "$dir" status --porcelain --untracked-files=no | wc -l)
    read -r ahead behind < <(git -C "$dir" rev-list --left-right --count main...origin/main 2>/dev/null || echo "0 0")

    local state=ok msg
    if [ "$branch" != main ]; then
        state=alone
        msg="on ${branch:-a detached HEAD}, not main"
        [ "$dirty" -gt 0 ] && msg="$msg, $dirty uncommitted"
        [ "$behind" -gt 0 ] && msg="$msg; main is $behind behind origin"
    elif [ "$dirty" -gt 0 ]; then
        state=alone
        msg="main with $dirty uncommitted change(s)"
        [ "$behind" -gt 0 ] && msg="$msg; $behind behind origin"
    elif [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        state=alone
        msg="main has diverged from origin ($ahead ahead, $behind behind)"
    elif [ "$ahead" -gt 0 ]; then
        state=alone
        msg="main is $ahead ahead of origin (unpushed commits)"
    elif [ "$behind" -gt 0 ]; then
        local old new
        old=$(git -C "$dir" rev-parse --short HEAD)
        if err=$(git -C "$dir" merge -q --ff-only origin/main 2>&1); then
            new=$(git -C "$dir" rev-parse --short HEAD)
            state=changed
            msg="pulled $old..$new ($behind commit(s))"
        else
            state=alone
            msg="$behind behind origin, fast-forward refused: ${err%%$'\n'*}"
        fi
    else
        msg="up to date"
    fi
    [ -n "$note" ] && [ "$state" = ok ] && state=alone
    case $note in *"fetch failed"*) state=failed ;; esac
    printf '%s\t%s%s\n' "$state" "$msg" "$note" > "$result"
}

labels=()
if [ $pull_kit -eq 1 ]; then
    update "$root" kit ""
    labels+=(kit)
fi
for i in "${!names[@]}"; do
    update "$root/${names[$i]}" "${names[$i]}" "${repos[$i]}" &
    labels+=("${names[$i]}")
done
wait

status=0
for label in "${labels[@]}"; do
    IFS=$'\t' read -r state msg < "$out/$label"
    [ "$state" = failed ] && status=1
    [ $quiet -eq 1 ] && [ "$state" = ok ] && continue
    echo "$label: $msg"
done
exit $status
