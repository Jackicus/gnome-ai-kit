#!/usr/bin/env bash
# What the kit's CI runs, and what to run before a kit pull request:
#
#   .gnome-ai-kit/scripts/check.sh
#
# - shellcheck over the kit's scripts and the hook and scripts each extension gets, and
#   the template's Python compiled;
# - every .json file parses, every workflow (the kit's and the template's) is valid YAML
#   when PyYAML is there to say so, and extensions.json lists each extension once, with a
#   repository, and every listed directory is one the kit ignores;
# - every backticked kit path in CLAUDE.md, .claude/rules/, the kit's own skills and the
#   plugin's skills exists (one starting .gnome-ai-kit/, .claude/rules/ or .github/; a
#   .github/ path may be the template's).
#
# Runs from the kit's root, the folder holding CLAUDE.md and .gnome-ai-kit/.
#
# Prints `check: ok` when all pass.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
k=.gnome-ai-kit

fail=0

shellcheck_cmd=()
if command -v shellcheck >/dev/null; then
    shellcheck_cmd=(shellcheck)
elif command -v uvx >/dev/null; then
    shellcheck_cmd=(uvx --quiet --from shellcheck-py shellcheck)
else
    echo "check: shellcheck is not installed (pacman -S shellcheck, or uv for uvx)" >&2
    exit 1
fi
"${shellcheck_cmd[@]}" "$k"/scripts/*.sh "$k"/template/.claude/kit.sh "$k"/template/scripts/*.sh || fail=1
for f in "$k"/template/scripts/*.py; do
    PYTHONPYCACHEPREFIX="$(mktemp -d)" python3 -m py_compile "$f" || { echo "check: $f does not compile" >&2; fail=1; }
done

# The workflows: the kit's own and the ones every extension gets.
yaml_python=(python3)
python3 -c 'import yaml' 2>/dev/null || { command -v uvx >/dev/null && yaml_python=(uvx --quiet --with pyyaml python3); }
if "${yaml_python[@]}" -c 'import yaml' 2>/dev/null; then
    for f in .github/workflows/*.yml "$k"/template/.github/workflows/*.yml; do
        "${yaml_python[@]}" -c 'import sys, yaml; d = yaml.safe_load(open(sys.argv[1])); assert d.get("jobs"), "no jobs"' "$f" \
            || { echo "check: $f is not a valid workflow" >&2; fail=1; }
    done
else
    echo "check: PyYAML is not installed; the workflows' YAML was not checked" >&2
fi

while IFS= read -r -d '' f; do
    python3 -m json.tool "$f" >/dev/null || { echo "check: $f is not valid JSON" >&2; fail=1; }
done < <(find . -name '*.json' -not -path './.git/*' -not -path './GNOME-*' -print0)

python3 - <<'EOF' || fail=1
import glob, os, re, sys

docs = ['CLAUDE.md', *glob.glob('.claude/rules/*.md'), *glob.glob('.claude/skills/*/SKILL.md'),
        *glob.glob('.gnome-ai-kit/plugin/skills/*/SKILL.md')]
prefixes = ('.gnome-ai-kit/', '.claude/rules/', '.github/')
missing = []
for doc in docs:
    with open(doc) as f:
        text = f.read()
    for token in re.findall(r'`([^`\s]+)`', text):
        if not token.startswith(prefixes) or re.search(r'[<>*{}…$]', token):
            continue
        path = token.rstrip('/')
        candidates = [path]
        if path.startswith('.github/'):
            candidates.append(os.path.join('.gnome-ai-kit/template', path))
        if not any(os.path.exists(c) for c in candidates):
            missing.append(f'{doc}: `{token}` does not exist')
for line in missing:
    print('check:', line, file=sys.stderr)
sys.exit(1 if missing else 0)
EOF

python3 - <<'EOF' || fail=1
import json, re, subprocess, sys

problems = []
extensions = json.load(open('.gnome-ai-kit/extensions.json'))['extensions']
for key in ('name', 'repo', 'alias'):
    values = [e.get(key) for e in extensions]
    if None in values or '' in values:
        problems.append(f'every extension needs its {key}')
    elif len(set(values)) != len(values):
        problems.append(f'two extensions share one {key}')
for e in extensions:
    if not re.fullmatch(r'[\w.-]+/[\w.-]+', e.get('repo', '')):
        problems.append(f'{e.get("name")}: repo is not OWNER/NAME')
    # The extensions are repositories of their own: the kit must ignore each directory.
    ignored = subprocess.run(['git', 'check-ignore', '-q', '--no-index', e.get('name', '') + '/'])
    if ignored.returncode != 0:
        problems.append(f'.gitignore does not ignore {e.get("name")}/')
for line in problems:
    print('check: extensions.json:', line, file=sys.stderr)
sys.exit(1 if problems else 0)
EOF

if [ $fail -ne 0 ]; then
    echo "check: FAILED" >&2
    exit 1
fi
echo "check: ok"
