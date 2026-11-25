#!/usr/bin/env python3
"""Publish a playtest build for the launcher.

Scans a game folder, packs every file that the previous build doesn't already
have into a new pack (zlib per file where it helps), writes manifest.json and
uploads it all as release assets. Unchanged files keep pointing into older
packs, so an update only downloads what changed.

Backends:
  --backend dir     --out DIR                 write assets into a folder (tests, rsync, any static host)
  --backend github  --repo OWNER/NAME --tag T  assets of a GitHub release (token in GITHUB_TOKEN)

Only the Python standard library is used.
"""
import argparse
import datetime
import fnmatch
import hashlib
import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zlib

PACK_LIMIT = 256 << 20         # bytes per pack before starting a new one
ZMAX = 16 << 20                # files above this are stored raw (the launcher streams them)
REPACK_BELOW = 0.5             # repack an old pack once less than half of it is still used
NO_Z_EXT = {'.png', '.jpg', '.jpeg', '.webp', '.ogg', '.mp3', '.opus', '.zip', '.pk3', '.pk4',
            '.gz', '.7z', '.xz', '.bz2', '.mp4', '.webm', '.ktx2', '.dds.gz'}


def log(*a):
    print(*a, file=sys.stderr, flush=True)


# ---------------------------------------------------------------- rules

def load_rules(path):
    with open(path, encoding='utf-8') as f:
        r = json.load(f)
    r.setdefault('include', ['**'])
    r.setdefault('exclude', [])
    r.setdefault('keep', [])
    r.setdefault('exec', [])
    return r


def match_any(rel, pats):
    for p in pats:
        if fnmatch.fnmatchcase(rel, p):
            return True
        # "dir/**" also matches the dir's files at any depth; "**/x" also matches top-level x
        if p.endswith('/**') and rel.startswith(p[:-2]):
            return True
        if p.startswith('**/') and fnmatch.fnmatchcase(rel, p[3:]):
            return True
    return False


def scan(src, rules):
    out = []
    for root, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in ('.git', '.launcher'))
        for name in sorted(files):
            full = os.path.join(root, name)
            rel = os.path.relpath(full, src).replace(os.sep, '/')
            if not match_any(rel, rules['include']) or match_any(rel, rules['exclude']):
                continue
            if name.endswith('.part') or os.path.islink(full):
                continue
            out.append(rel)
    return out


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------- backends

class DirBackend:
    def __init__(self, out):
        self.out = out
        os.makedirs(out, exist_ok=True)

    def list(self):
        return {n: os.path.getsize(os.path.join(self.out, n)) for n in os.listdir(self.out)
                if os.path.isfile(os.path.join(self.out, n))}

    def read(self, name):
        p = os.path.join(self.out, name)
        if not os.path.exists(p):
            return None
        with open(p, 'rb') as f:
            return f.read()

    def upload(self, name, path):
        tmp = os.path.join(self.out, '.' + name + '.tmp')
        with open(path, 'rb') as a, open(tmp, 'wb') as b:
            while True:
                c = a.read(1 << 20)
                if not c:
                    break
                b.write(c)
        os.replace(tmp, os.path.join(self.out, name))

    def delete(self, name):
        os.remove(os.path.join(self.out, name))

    def finish(self, version, notes):
        pass


class GitHubBackend:
    API = 'https://api.github.com'

    def __init__(self, repo, tag, token, commit=None, title=None):
        self.repo, self.tag, self.token = repo, tag, token
        self.commit, self.title = commit, title
        self.release = self._get_or_create()
        self.assets = {a['name']: a for a in self.release.get('assets', [])}

    def _req(self, method, url, data=None, headers=None, raw=False, ok=(200, 201, 204)):
        h = {'Authorization': 'Bearer ' + self.token, 'Accept': 'application/vnd.github+json',
             'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'playtest-publish'}
        h.update(headers or {})
        body = data
        if isinstance(data, (dict, list)):
            body = json.dumps(data).encode()
            h['Content-Type'] = 'application/json'
        for attempt in range(5):
            req = urllib.request.Request(url, data=body, method=method, headers=h)
            try:
                with urllib.request.urlopen(req, timeout=600) as resp:
                    payload = resp.read()
                    if raw:
                        return payload
                    return json.loads(payload) if payload else None
            except urllib.error.HTTPError as e:
                if e.code == 404 and method == 'GET':
                    return None
                if e.code in (500, 502, 503, 504) and attempt < 4:
                    time.sleep(2 * (attempt + 1))
                    if hasattr(body, 'seek'):
                        body.seek(0)
                    continue
                raise RuntimeError(f'{method} {url}: HTTP {e.code} {e.read()[:500]!r}')
            except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
                if attempt < 4:
                    time.sleep(2 * (attempt + 1))
                    if hasattr(body, 'seek'):
                        body.seek(0)
                    continue
                raise

    def _get_or_create(self):
        r = self._req('GET', f'{self.API}/repos/{self.repo}/releases/tags/{urllib.parse.quote(self.tag)}')
        if r:
            # tags API omits nothing, but assets past 100 need paging
            assets, page = [], 1
            while True:
                chunk = self._req('GET', f'{self.API}/repos/{self.repo}/releases/{r["id"]}/assets?per_page=100&page={page}')
                assets += chunk or []
                if not chunk or len(chunk) < 100:
                    break
                page += 1
            r['assets'] = assets
            return r
        body = {'tag_name': self.tag, 'name': self.title or self.tag, 'prerelease': True,
                'body': 'Playtest channel. The launcher reads manifest.json from this release.'}
        if self.commit:
            body['target_commitish'] = self.commit
        log(f'creating release {self.tag}')
        r = self._req('POST', f'{self.API}/repos/{self.repo}/releases', body)
        r['assets'] = []
        return r

    def list(self):
        return {n: a['size'] for n, a in self.assets.items()}

    def read(self, name):
        a = self.assets.get(name)
        if not a:
            return None
        return self._req('GET', a['url'], headers={'Accept': 'application/octet-stream'}, raw=True)

    def upload(self, name, path):
        if name in self.assets:
            self.delete(name)
        size = os.path.getsize(path)
        url = self.release['upload_url'].split('{')[0] + '?name=' + urllib.parse.quote(name)
        with open(path, 'rb') as f:
            a = self._req('POST', url, data=f, headers={'Content-Type': 'application/octet-stream',
                                                         'Content-Length': str(size)})
        self.assets[name] = a

    def delete(self, name):
        a = self.assets.pop(name)
        self._req('DELETE', f'{self.API}/repos/{self.repo}/releases/assets/{a["id"]}')

    def finish(self, version, notes):
        body = f'**Current build: {version}**\n\n{notes}\n\nPlaytest channel. The launcher reads `manifest.json` from this release.'
        self._req('PATCH', f'{self.API}/repos/{self.repo}/releases/{self.release["id"]}',
                  {'body': body[:120000], 'name': (self.title or self.tag)})


# ---------------------------------------------------------------- packing

class PackWriter:
    def __init__(self, tmpdir):
        self.tmpdir = tmpdir
        self.done = []      # (tmp path, final name, size)
        self.f = None

    def _open(self):
        fd, self.path = tempfile.mkstemp(dir=self.tmpdir, suffix='.pack')
        self.f = os.fdopen(fd, 'wb')
        self.h = hashlib.sha256()
        self.size = 0

    def add(self, data):
        if self.f is None or (self.size and self.size + len(data) > PACK_LIMIT):
            self.close()
            self._open()
        off = self.size
        self.f.write(data)
        self.h.update(data)
        self.size += len(data)
        return len(self.done), off   # index of the pack being written

    def close(self):
        if self.f is None:
            return
        self.f.close()
        name = 'pack-' + self.h.hexdigest()[:20] + '.bin'
        self.done.append((self.path, name, self.size))
        self.f = None


def encode(path, size):
    with open(path, 'rb') as f:
        data = f.read()
    ext = os.path.splitext(path)[1].lower()
    if size <= ZMAX and size >= 512 and ext not in NO_Z_EXT:
        z = zlib.compress(data, 9)
        if len(z) < size * 0.95:
            return z, 1
    return data, 0


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--src', required=True, help='game folder to publish')
    ap.add_argument('--rules', required=True, help='publish.json for this game')
    ap.add_argument('--backend', choices=['dir', 'github'], default='dir')
    ap.add_argument('--out', help='dir backend: output folder')
    ap.add_argument('--repo', help='github backend: owner/name')
    ap.add_argument('--tag', help='github backend: release tag (the channel)')
    ap.add_argument('--version')
    ap.add_argument('--notes', default='')
    ap.add_argument('--notes-file')
    ap.add_argument('--commit', default='')
    ap.add_argument('--branch', default='')
    ap.add_argument('--launcher-windows')
    ap.add_argument('--launcher-linux')
    ap.add_argument('--asset', action='append', default=[], metavar='NAME=PATH',
                    help='extra file to upload as a release asset (for example the tester zip)')
    ap.add_argument('--full', action='store_true', help='repack everything')
    ap.add_argument('--dry-run', action='store_true', help='build the packs and manifest locally, upload nothing')
    a = ap.parse_args()

    rules = load_rules(a.rules)
    version = a.version or datetime.datetime.now(datetime.timezone.utc).strftime('%Y.%m%d.%H%M') + (('-' + a.commit[:7]) if a.commit else '')
    notes = a.notes
    if a.notes_file:
        with open(a.notes_file, encoding='utf-8') as f:
            notes = f.read().strip()

    if a.backend == 'dir':
        if not a.out:
            ap.error('--out is required for the dir backend')
        be = DirBackend(a.out)
    else:
        token = os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN')
        if not (a.repo and a.tag and token):
            ap.error('github backend needs --repo, --tag and GITHUB_TOKEN')
        be = GitHubBackend(a.repo, a.tag, token, a.commit, rules.get('release_title'))

    remote = be.list()
    prev = None
    raw = be.read('manifest.json')
    if raw:
        try:
            prev = json.loads(raw)
        except ValueError:
            log('previous manifest is unreadable, doing a full publish')
    known = {}   # sha -> (pack name, offset, length, z)
    pack_used = {}
    if prev and not a.full:
        pnames = [p['name'] for p in prev.get('packs', [])]
        for f in prev.get('files', []):
            pn = pnames[f['pack']]
            if pn in remote:
                known[f['sha256']] = (pn, f['offset'], f['length'], f.get('z', 0))

    files = scan(a.src, rules)
    missing = [r for r in rules.get('require', []) if r not in files]
    if missing:
        sys.exit('publish stopped, these required files are missing or excluded: ' + ', '.join(missing))
    log(f'{len(files)} files to publish from {a.src}')
    entries = []
    for rel in files:
        full = os.path.join(a.src, rel)
        size = os.path.getsize(full)
        entries.append({'path': rel, 'sha256': sha256_file(full), 'size': size,
                        'x': 1 if match_any(rel, rules['exec']) else 0,
                        'keep': 1 if match_any(rel, rules['keep']) else 0})

    # how much of each old pack the new build still uses
    used = {}
    for e in entries:
        k = known.get(e['sha256'])
        if k:
            used[k[0]] = used.get(k[0], 0) + k[2]
    for pn, n in used.items():
        if n < remote.get(pn, 0) * REPACK_BELOW:
            log(f'repacking {pn}: only {n * 100 // max(remote[pn], 1)}% still used')
            for sha in [s for s, k in known.items() if k[0] == pn]:
                del known[sha]

    tmpdir = tempfile.mkdtemp(prefix='playtest-publish-')
    pw = PackWriter(tmpdir)
    pending = {}   # sha -> (pack index in pw.done, offset, length, z)
    new_bytes = 0
    for e in entries:
        sha = e['sha256']
        if sha in known or sha in pending:
            continue
        data, z = encode(os.path.join(a.src, e['path']), e['size'])
        idx, off = pw.add(data)
        pending[sha] = (idx, off, len(data), z)
        new_bytes += len(data)
    pw.close()
    new_packs = pw.done
    log(f'{len(pending)} new or changed files, {new_bytes / 1048576:.1f} MB in {len(new_packs)} new pack(s)')

    packs, pindex = [], {}

    def pack_ref(name, size):
        if name not in pindex:
            pindex[name] = len(packs)
            packs.append({'name': name, 'size': size})
        return pindex[name]

    for e in entries:
        sha = e['sha256']
        if sha in pending:
            idx, off, ln, z = pending[sha]
            tmp, name, psize = new_packs[idx]
            e['pack'] = pack_ref(name, psize)
        else:
            name, off, ln, z = known[sha]
            e['pack'] = pack_ref(name, remote[name])
        e['offset'], e['length'], e['z'] = off, ln, z
        if not e['x']:
            del e['x']
        if not e['keep']:
            del e['keep']

    manifest = {
        'format': 1,
        'game': rules.get('game', ''),
        'title': rules.get('title', ''),
        'version': version,
        'commit': a.commit,
        'branch': a.branch,
        'published': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'notes': notes,
        'packs': packs,
        'files': entries,
    }
    if rules.get('run'):
        manifest['run'] = rules['run']
    launcher_uploads = []
    for osname, path in (('windows', a.launcher_windows), ('linux', a.launcher_linux)):
        if not path:
            if prev and prev.get('launcher', {}).get(osname) and prev['launcher'][osname]['name'] in remote:
                manifest.setdefault('launcher', {})[osname] = prev['launcher'][osname]
            continue
        sha = sha256_file(path)
        name = f'launcher-{osname}-{sha[:16]}' + ('.exe' if osname == 'windows' else '')
        manifest.setdefault('launcher', {})[osname] = {'name': name, 'sha256': sha, 'size': os.path.getsize(path)}
        if name not in remote:
            launcher_uploads.append((name, path))

    mpath = os.path.join(tmpdir, 'manifest.json')
    with open(mpath, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=1)

    if a.dry_run:
        out = a.out or tmpdir
        log(f'dry run: manifest and packs left in {tmpdir}')
        print(json.dumps({'version': version, 'files': len(entries), 'new_files': len(pending),
                          'new_bytes': new_bytes, 'packs': len(packs), 'tmp': tmpdir}))
        return

    for tmp, name, size in new_packs:
        log(f'uploading {name} ({size / 1048576:.1f} MB)')
        be.upload(name, tmp)
        os.remove(tmp)
    for name, path in launcher_uploads:
        log(f'uploading {name}')
        be.upload(name, path)
    extra = []
    for spec in a.asset:
        name, _, path = spec.partition('=')
        if not name or not path or '/' in name:
            sys.exit(f'bad --asset {spec!r}, use NAME=PATH')
        extra.append(name)
        log(f'uploading {name}')
        be.upload(name, path)
    # the switch: everything the manifest points at is in place before it changes
    be.upload('manifest.json', mpath)
    be.finish(version, notes)

    # keep what this and the previous manifest use, so a download that started
    # just before this publish can still finish
    keep = {'manifest.json'} | {p['name'] for p in packs} | {l['name'] for l in manifest.get('launcher', {}).values()}
    if prev:
        keep |= {p['name'] for p in prev.get('packs', [])}
        keep |= {l['name'] for l in prev.get('launcher', {}).values()}
    for name in list(be.list()):
        if name not in keep and (name.startswith('pack-') or name.startswith('launcher-')):
            log(f'removing unused {name}')
            be.delete(name)
    total = sum(p['size'] for p in packs)
    print(json.dumps({'version': version, 'files': len(entries), 'new_files': len(pending),
                      'new_bytes': new_bytes, 'install_bytes': total}))


if __name__ == '__main__':
    main()
