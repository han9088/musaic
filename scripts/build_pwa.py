#!/usr/bin/env python3
"""Build a self-contained Flutter PWA using only Python's standard library."""
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def package(build: Path, template: Path) -> tuple[int, int]:
    index = build / "index.html"
    html = index.read_text()
    tag = '<script src="pwa.js" defer></script>'
    if tag not in html:
        index.write_text(html.replace('</body>', f'  {tag}\n</body>'))
    files = sorted(
        p for p in build.rglob('*')
        if p.is_file() and not p.name.endswith(('.map', '.symbols'))
        and p.name not in {'service-worker.js', 'flutter_service_worker.js', '.last_build_id',
                          '_headers', '_redirects', '.assetsignore'}
    )
    digest = hashlib.sha256(template.read_bytes())
    size = 0
    manifest = []
    for path in files:
        data = path.read_bytes()
        digest.update(path.relative_to(build).as_posix().encode())
        checksum = hashlib.sha256(data).digest()
        digest.update(checksum)
        size += len(data)
        manifest.append({
            'path': path.relative_to(build).as_posix(),
            'integrity': 'sha256-' + base64.b64encode(checksum).decode(),
        })
    script = template.read_text().replace('__VERSION__', json.dumps(digest.hexdigest()[:24]))
    script = script.replace('__FILES__', json.dumps(manifest))
    (build / 'service-worker.js').write_text(script)
    return len(files), size


if __name__ == '__main__':
    subprocess.run(
        ['mise', 'exec', '--', 'flutter', 'build', 'web', '--release',
         '--no-web-resources-cdn', *sys.argv[1:]], cwd=ROOT, check=True,
    )
    count, size = package(ROOT / 'build/web', ROOT / 'scripts/pwa_service_worker.js')
    print(f'PWA: {count} bundled files, {size / 1024 / 1024:.1f} MiB offline cache')
