#!/usr/bin/env bash
# Scaffolds a new extension beside the kit, ready for its first commit.
#
#   .gnome-ai-kit/scripts/new-extension.sh NAME SLUG DESCRIPTION [DIR]
#
#   NAME         what people read: "Clipboard Peek"
#   SLUG         the UUID before @jackicus, lower case and hyphens: clipboard-peek
#   DESCRIPTION  one sentence, as metadata.json and the README open with
#   DIR          where to make it; default: GNOME-<NAME with hyphens> beside the kit
#
# Renders template/skeleton/ (an extension.js, a lib/app.js with a top-bar icon and
# a setting, its preferences and schema, ext.conf, Makefile, CLAUDE.md, README,
# LICENSE), runs scripts/sync.sh over it for the files every extension shares,
# writes package-lock.json, and makes a git repository on main with nothing
# committed. The new-extension skill (.claude/skills/new-extension/) does the rest:
# the GitHub repository, the first push, the manifest, protection.

set -euo pipefail

kit=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$kit")
[ $# -ge 3 ] || { sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }
name=$1 slug=$2 description=$3
[[ $slug =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]] || { echo "new-extension.sh: SLUG is lower case words joined by hyphens: $slug" >&2; exit 2; }
repo="GNOME-$(tr ' ' '-' <<<"$name")"
dir=${4:-$root/$repo}
class=$(sed -E 's/[^A-Za-z0-9 ]//g; s/(^| )([a-z])/\1\u\2/g; s/ //g' <<<"$name")
[ -e "$dir" ] && { echo "new-extension.sh: $dir exists" >&2; exit 1; }
[[ $name =~ ^[A-Za-z0-9]+( [A-Za-z0-9]+)*$ ]] || { echo "new-extension.sh: NAME is words of letters and digits: $name" >&2; exit 2; }

mkdir -p "$dir"
cp -r "$kit/template/skeleton/." "$dir/"
mv "$dir/src/schemas/org.gnome.shell.extensions.@SLUG@.gschema.xml" \
   "$dir/src/schemas/org.gnome.shell.extensions.$slug.gschema.xml"
while IFS= read -r -d '' file; do
    NAME=$name SLUG=$slug CLASS=$class REPO=$repo DESCRIPTION=$description python3 - "$file" <<'PY'
import json, os, sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
for key in ('NAME', 'SLUG', 'CLASS', 'REPO', 'DESCRIPTION'):
    value = os.environ[key]
    if path.endswith('.json'):
        value = json.dumps(value)[1:-1]
    text = text.replace(f'@{key}@', value)
open(path, 'w', encoding='utf-8').write(text)
PY
done < <(find "$dir" -type f ! -name LICENSE -print0)
if grep -rn '@[A-Z]*@' "$dir" --exclude=LICENSE; then
    echo "new-extension.sh: a placeholder was left unfilled" >&2
    exit 1
fi

git -C "$dir" init -q -b main
"$kit/scripts/sync.sh" "$dir"
(cd "$dir" && npm install --package-lock-only --no-audit --no-fund >/dev/null)
echo "Made $dir ($name, $slug@jackicus, class prefix $class). Nothing is committed yet."
