import base64
import hashlib
import json
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('build_pwa', ROOT / 'scripts/build_pwa.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PwaBuildTest(unittest.TestCase):
    def test_version_is_deterministic_and_tracks_files_and_worker(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('<body></body>')
            (root / 'main.dart.js').write_text('v1')
            (root / 'main.dart.js.map').write_text('excluded')
            for name in ('_headers', '_redirects', '.assetsignore'):
                (root / name).write_text('deployment configuration')
            template = root.parent / (root.name + '-worker.js')
            try:
                template.write_text('const VERSION=__VERSION__; const FILES=__FILES__;')
                self.assertEqual(module.package(root, template)[0], 2)
                first = (root / 'service-worker.js').read_text()
                module.package(root, template)
                self.assertEqual(first, (root / 'service-worker.js').read_text())
                self.assertNotIn('.map', first)
                for name in ('_headers', '_redirects', '.assetsignore'):
                    self.assertNotIn(name, first)
                manifest = json.loads(first.split('const FILES=')[1].rstrip(';'))
                entry = next(item for item in manifest if item['path'] == 'main.dart.js')
                self.assertEqual(entry['integrity'], 'sha256-' + base64.b64encode(hashlib.sha256(b'v1').digest()).decode())
                self.assertEqual((root / 'index.html').read_text().count('src="pwa.js"'), 1)
                (root / 'main.dart.js').write_text('v2')
                module.package(root, template)
                second = (root / 'service-worker.js').read_text()
                self.assertNotEqual(first, second)
                template.write_text(template.read_text() + '// changed')
                module.package(root, template)
                self.assertNotEqual(second, (root / 'service-worker.js').read_text())
            finally:
                template.unlink()


if __name__ == '__main__':
    unittest.main()
