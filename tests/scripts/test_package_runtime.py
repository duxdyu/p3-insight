"""Package completeness and failure boundaries without starting Delphi or games."""
from pathlib import Path
import importlib.util
import json
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('package_runtime', ROOT / 'scripts/package_runtime.py')
package_runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package_runtime)


class PackageTests(unittest.TestCase):
    def setUp(self):
        base = ROOT / 'build/package-tests'
        base.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=base)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        source = self.root / 'runtime/InjLib.dll'
        source.parent.mkdir()
        source.write_bytes(b'asset')
        (source.parent / 'manifest.json').write_text(json.dumps(dict(files=[
            dict(source='runtime/InjLib.dll', target='InjLib.dll',
                 sha256=package_runtime.sha(source))])), 'utf-8')
        rows = []
        for name in package_runtime.BINARIES.values():
            binary = self.root / 'build/compiled/p3-insight' / name
            binary.parent.mkdir(parents=True, exist_ok=True)
            binary.write_bytes(name.encode())
            rows.append(dict(path=str(binary), sha256=package_runtime.sha(binary)))
        logs = self.root / 'build/logs'
        logs.mkdir()
        (logs / 'PI-build-result.json').write_text(json.dumps(
            dict(success=True, outputs=rows)), 'utf-8')

    def test_complete_package_and_repeat_build(self):
        for _ in range(2):
            output = package_runtime.package(self.root)
            self.assertEqual({p.name for p in output.iterdir()},
                             {'InjLib.dll', *package_runtime.BINARIES})
            self.assertEqual((output / 'PI模式启动游戏.exe').read_bytes(),
                             b'PIProductionLauncher.exe')

    def test_missing_asset_preserves_previous_package(self):
        output = package_runtime.package(self.root)
        before = {p.name: p.read_bytes() for p in output.iterdir()}
        (self.root / 'runtime/InjLib.dll').unlink()
        with self.assertRaisesRegex(RuntimeError, 'Runtime asset missing'):
            package_runtime.package(self.root)
        self.assertEqual(before, {p.name: p.read_bytes() for p in output.iterdir()})

    def test_changed_binary_is_not_packaged(self):
        (self.root / 'build/compiled/p3-insight/p3insight.dll').write_bytes(b'stale')
        with self.assertRaisesRegex(RuntimeError, 'Build output missing or changed'):
            package_runtime.package(self.root)
        self.assertFalse((self.root / 'build/p3-insight').exists())

    def test_unexpected_user_file_is_preserved(self):
        output = package_runtime.package(self.root)
        (output / 'personal.txt').write_bytes(b'keep')
        with self.assertRaisesRegex(RuntimeError, 'Unexpected files'):
            package_runtime.package(self.root)
        self.assertEqual((output / 'personal.txt').read_bytes(), b'keep')


if __name__ == '__main__':
    unittest.main()
