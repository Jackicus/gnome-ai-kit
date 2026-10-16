#!/usr/bin/env bash
# Makes the extensions' release tags permanent: a repository ruleset "Release tags" on
# refs/tags/v* that refuses deleting, moving or force-pushing such a tag, with nobody
# allowed to bypass it. Creating a tag stays allowed, so a release is still a pushed tag.
#
#   .gnome-ai-kit/scripts/protect-tags.sh [NAME|ALIAS|OWNER/REPO...]
#
# By default every extension extensions.json lists. Running it again updates the ruleset
# in place. Run it for an extension once release.yml has reached it (the rollout skill
# says when).

set -euo pipefail

kit=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ruleset_name="Release tags"

case ${1:-} in
    -h | --help) sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

# OWNER/REPO for each argument: a name or alias from extensions.json, or OWNER/REPO itself.
mapfile -t repos < <(python3 - "$kit/extensions.json" "$@" <<'EOF'
import json, sys

extensions = json.load(open(sys.argv[1]))['extensions']
wanted = sys.argv[2:]
if not wanted:
    for e in extensions:
        print(e['repo'])
for w in wanted:
    match = [e['repo'] for e in extensions if w in (e['name'], e['alias'], e['repo'])]
    if match:
        print(match[0])
    elif '/' in w:
        print(w)
    else:
        print(f'protect-tags.sh: {w} is not in extensions.json', file=sys.stderr)
        sys.exit(2)
EOF
)

body=$(python3 -c '
import json, sys
print(json.dumps({
    "name": sys.argv[1],
    "target": "tag",
    "enforcement": "active",
    "bypass_actors": [],
    "conditions": {"ref_name": {"include": ["refs/tags/v*"], "exclude": []}},
    "rules": [{"type": "deletion"}, {"type": "non_fast_forward"}, {"type": "update"}],
}))' "$ruleset_name")

status=0
for repo in "${repos[@]}"; do
    id=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$ruleset_name\") | .id" 2>/dev/null) || {
        echo "$repo: could not list its rulesets"
        status=1
        continue
    }
    if [ -n "$id" ]; then
        gh api -X PUT "repos/$repo/rulesets/$id" --input - <<< "$body" >/dev/null && verb=updated
    else
        gh api -X POST "repos/$repo/rulesets" --input - <<< "$body" >/dev/null && verb=created
    fi || { echo "$repo: could not write the ruleset"; status=1; continue; }
    rules=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$ruleset_name\") | .id" |
        xargs -I{} gh api "repos/$repo/rulesets/{}" --jq '"\(.enforcement): \([.rules[].type] | join(", ")) on \(.conditions.ref_name.include | join(", "))"')
    echo "$repo: $verb \"$ruleset_name\" ($rules)"
done
exit $status
