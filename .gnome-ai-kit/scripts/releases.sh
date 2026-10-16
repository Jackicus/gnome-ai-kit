#!/usr/bin/env bash
# Where every extension stands on releases, read from GitHub and extensions.gnome.org:
#
#   .gnome-ai-kit/scripts/releases.sh [--json] [--prs] [NAME|ALIAS...]
#
# Per extension: version-name on main, the last v* tag and its date, the pull requests
# merged since it, main's CI, the last Release workflow run, what extensions.gnome.org
# carries for GNOME Shell 50, and the version to cut next (any feat/ pull request since
# the tag: minor; otherwise a patch; never released: version-name as it is). Then the
# warnings. --prs lists the unreleased pull requests' titles; --json prints it all as JSON.
# Reads only; never tags, releases or changes anything.

set -euo pipefail

kit=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

case ${1:-} in
    -h | --help) sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

exec python3 - "$kit/extensions.json" "$@" <<'EOF'
import base64, io, json, re, subprocess, sys, urllib.error, urllib.request, zipfile
from concurrent.futures import ThreadPoolExecutor

manifest, *args = sys.argv[1:]
as_json = '--json' in args
list_prs = '--prs' in args
wanted = [a for a in args if not a.startswith('--')]
extensions = json.load(open(manifest))['extensions']
if wanted:
    unknown = [w for w in wanted if not any(w in (e['name'], e['alias']) for e in extensions)]
    if unknown:
        sys.exit(f'releases.sh: not in extensions.json: {" ".join(unknown)}')
    extensions = [e for e in extensions if e['name'] in wanted or e['alias'] in wanted]

SHELL = '50'


def gh(*args):
    r = subprocess.run(['gh', *args], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip() or f'gh {" ".join(args)} failed')
    return r.stdout


def gh_json(*args):
    return json.loads(gh(*args) or 'null')


def version_key(name):
    return [int(p) if p.isdigit() else p for p in re.split(r'[.-]', name.lstrip('v'))]


def bump(version, part):
    nums = [int(p) for p in re.findall(r'\d+', version)] or [0]
    while len(nums) < 2:
        nums.append(0)
    if part == 'minor':
        return f'{nums[0]}.{nums[1] + 1}'
    nums = nums[:3] + [0] * (3 - len(nums[:3]))
    return f'{nums[0]}.{nums[1]}.{nums[2] + 1}'


def ego(uuid):
    url = f'https://extensions.gnome.org/extension-info/?uuid={uuid}&shell_version={SHELL}'
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            info = json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return {'published': False}
        return {'error': f'HTTP {e.code}'}
    except Exception as e:  # offline, timeout
        return {'error': str(e)}
    result = {'published': True, 'version': info.get('version'),
              'link': 'https://extensions.gnome.org' + info.get('link', '')}
    # The API has no version-name; the published zip's metadata.json does.
    if info.get('download_url'):
        try:
            with urllib.request.urlopen('https://extensions.gnome.org' + info['download_url'],
                                        timeout=30) as r:
                meta = json.loads(zipfile.ZipFile(io.BytesIO(r.read())).read('metadata.json'))
            result['version_name'] = meta.get('version-name')
        except Exception:
            pass
    return result


def last_run(repo, workflow):
    try:
        runs = gh_json('run', 'list', '-R', repo, '-w', workflow, '-L', '1',
                       '--json', 'conclusion,status,headBranch,url')
    except RuntimeError:
        return None  # no such workflow yet
    if not runs:
        return {'state': 'never run'}
    run = runs[0]
    return {'state': run['conclusion'] or run['status'], 'ref': run['headBranch'], 'url': run['url']}


def look(e):
    repo = e['repo']
    out = {'name': e['name'], 'alias': e['alias'], 'repo': repo, 'warnings': []}
    try:
        meta = json.loads(base64.b64decode(
            gh('api', f'repos/{repo}/contents/src/metadata.json?ref=main', '--jq', '.content')))
    except Exception as err:
        out['error'] = f'no src/metadata.json on main: {err}'
        return out
    out['uuid'] = meta.get('uuid')
    out['version_name'] = meta.get('version-name')
    if 'version' in meta:
        out['warnings'].append('metadata.json sets "version": extensions.gnome.org assigns it')

    tags = [t for t in gh('api', f'repos/{repo}/tags', '--paginate', '--jq', '.[].name').split()
            if t.startswith('v')]
    releases = gh_json('release', 'list', '-R', repo, '-L', '100',
                       '--json', 'tagName,isPrerelease,publishedAt')
    released = {r['tagName'] for r in releases}
    out['tags'] = sorted(tags, key=version_key)
    last = max(tags, key=version_key) if tags else None
    out['last_tag'] = last
    since = None
    if last:
        since = gh('api', f'repos/{repo}/commits/{last}', '--jq', '.commit.committer.date').strip()
        out['last_tag_date'] = since[:10]

    prs = gh_json('pr', 'list', '-R', repo, '--state', 'merged', '--base', 'main', '-L', '300',
                  '--json', 'number,title,headRefName,mergedAt')
    unreleased = [p for p in prs if (since is None or p['mergedAt'] > since)
                  and not p['headRefName'].startswith('release/')]
    unreleased.sort(key=lambda p: p['mergedAt'])
    out['unreleased'] = [{'number': p['number'], 'title': p['title'], 'branch': p['headRefName']}
                         for p in unreleased]

    vn = out['version_name'] or '0'
    if not last:
        out['next'] = vn
    elif not unreleased:
        out['next'] = None
    elif any(p['headRefName'].startswith('feat/') for p in unreleased):
        out['next'] = bump(last.lstrip('v').split('-')[0], 'minor')
    else:
        out['next'] = bump(last.lstrip('v').split('-')[0], 'patch')

    out['ci'] = last_run(repo, 'CI')
    out['release_run'] = last_run(repo, 'Release')
    out['ego'] = ego(out['uuid']) if out['uuid'] else {'error': 'no uuid'}

    if f'v{vn}' in tags and unreleased:
        out['warnings'].append(f'version-name {vn} is already tagged and {len(unreleased)} '
                               'pull request(s) are unreleased: the next release bumps it')
    for t in tags:
        if t not in released:
            out['warnings'].append(f'{t} has no GitHub release')
    for r in releases:
        assets = gh_json('release', 'view', r['tagName'], '-R', repo, '--json', 'assets')['assets']
        if not any(a['name'].endswith('.shell-extension.zip') for a in assets):
            out['warnings'].append(f'release {r["tagName"]} has no .shell-extension.zip')
    if out['ci'] and out['ci']['state'] not in ('success', 'never run'):
        out['warnings'].append(f'main\'s CI is {out["ci"]["state"]}')
    if out['release_run'] and out['release_run']['state'] not in ('success', 'never run'):
        out['warnings'].append(f'the last Release run ({out["release_run"]["ref"]}) is '
                               f'{out["release_run"]["state"]}: {out["release_run"]["url"]}')
    pub = out['ego']
    if pub.get('published') and pub.get('version_name') and last and \
            version_key(pub['version_name']) > version_key(last):
        out['warnings'].append(f'extensions.gnome.org has {pub["version_name"]}, newer than {last}')
    return out


with ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(look, extensions))

if as_json:
    print(json.dumps(results, indent=2))
    sys.exit(0)


def ego_cell(p):
    if 'error' in p:
        return f'? ({p["error"]})'
    if not p.get('published'):
        return 'not published'
    return f'{p.get("version_name") or "?"} (v{p.get("version")})'


rows = [('Extension', 'version', 'last tag', 'unreleased', 'CI', 'release run', 'e.g.o', 'next')]
for r in results:
    if 'error' in r:
        rows.append((r['name'], '?', r['error'], '', '', '', '', ''))
        continue
    tag = f'{r["last_tag"]} {r["last_tag_date"]}' if r['last_tag'] else 'none'
    rows.append((r['name'], r['version_name'] or '?', tag, str(len(r['unreleased'])),
                 (r['ci'] or {}).get('state', 'no workflow'),
                 (r['release_run'] or {}).get('state', 'no workflow'),
                 ego_cell(r['ego']), r['next'] or '-'))
widths = [max(len(row[i]) for row in rows) for i in range(len(rows[0]))]
for row in rows:
    print('  '.join(cell.ljust(w) for cell, w in zip(row, widths)).rstrip())

for r in results:
    if list_prs and r.get('unreleased'):
        print(f'\n{r["name"]}: unreleased')
        for p in r['unreleased']:
            print(f'  #{p["number"]} {p["title"]} ({p["branch"]})')
warnings = [f'{r["name"]}: {w}' for r in results for w in r.get('warnings', [])]
if warnings:
    print()
    print('\n'.join(warnings))
EOF
