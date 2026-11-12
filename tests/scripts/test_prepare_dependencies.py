"""Dependency preparation boundaries; no IDE, game, or system settings used."""
from pathlib import Path
import importlib.util
import io
import os
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('prepare', ROOT/'scripts/prepare_dependencies.py')
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class PreparationTests(unittest.TestCase):
    def setUp(self):
        base = Path(os.environ.get('PI_DEPENDENCY_TEST_TMP', str(ROOT/'build/dependency-tests')))
        base.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=base)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def fixture(self):
        cache = self.root/'cache'
        cache.mkdir()
        archive = cache/'fixture.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr('upstream/unit.pas', b'original')
            z.writestr('upstream/template.inc', b'config')
            z.writestr('upstream/../../escape.txt', b'excluded')
        source = dict(id='fixture', cache_name=archive.name, sha256=prepare.sha(archive.read_bytes()),
                      archive_prefix='upstream/', destination='lib', url='https://example.invalid/fixture.zip')
        recipe = dict(input_sha256=prepare.sha(b'original'), output_sha256=prepare.sha(b'adapted'),
                      edits=[dict(old='original', new='adapted')])
        recipes = {'lib/unit.pas': recipe,
                   'lib/new.inc': dict(copy_from='lib/template.inc', output_sha256=prepare.sha(b'config'))}
        lock = {'lib/unit.pas': prepare.sha(b'adapted'), 'lib/template.inc': prepare.sha(b'config'),
                'lib/new.inc': prepare.sha(b'config')}
        return cache, source, recipes, lock

    def test_clean_offline_reconstruction_and_idempotence(self):
        cache, source, recipes, lock = self.fixture()
        output = self.root/'output'
        with patch.object(prepare.urllib.request, 'urlopen', side_effect=AssertionError('offline')):
            prepare.prepare_vendor(output, lock, [source], recipes, cache, True)
            prepare.prepare_vendor(output, lock, [source], recipes, cache, True)
        prepare.verify_vendor(output/'vendor', lock)
        self.assertEqual((output/'vendor/lib/unit.pas').read_bytes(), b'adapted')
        self.assertFalse(list(output.rglob('escape.txt')))
        self.assertFalse(list((output/'build').glob('dependency-stage-*')))

    def test_bad_final_hash_never_promotes_partial_vendor(self):
        cache, source, recipes, lock = self.fixture()
        lock['lib/new.inc'] = '0'*64
        output = self.root/'output'
        with self.assertRaisesRegex(RuntimeError, 'Dependency mismatch'):
            prepare.prepare_vendor(output, lock, [source], recipes, cache, True)
        self.assertFalse((output/'vendor').exists())
        self.assertFalse(list((output/'build').glob('dependency-stage-*')))

    def test_modified_existing_vendor_is_preserved(self):
        output = self.root/'output'
        target = output/'vendor/user.pas'
        target.parent.mkdir(parents=True)
        target.write_bytes(b'personal changes')
        with self.assertRaisesRegex(RuntimeError, 'Dependency mismatch'):
            prepare.prepare_vendor(output, {'user.pas': prepare.sha(b'expected')})
        self.assertEqual(target.read_bytes(), b'personal changes')

    def test_corrupt_cache_is_not_accepted_or_overwritten(self):
        cache, source, _, _ = self.fixture()
        target = cache/source['cache_name']
        target.write_bytes(b'bad cache')
        with patch.object(prepare.urllib.request, 'urlopen', side_effect=AssertionError('no redownload')):
            with self.assertRaisesRegex(RuntimeError, 'Cached archive hash mismatch'):
                prepare.get_archive(source, cache)
        self.assertEqual(target.read_bytes(), b'bad cache')

    def test_bad_download_is_removed(self):
        source = dict(id='fake', cache_name='fake.zip', sha256='0'*64, url='https://example.invalid/fake.zip')
        cache = self.root/'cache'
        with patch.object(prepare.urllib.request, 'urlopen', return_value=io.BytesIO(b'bad download')):
            with self.assertRaisesRegex(RuntimeError, 'Downloaded archive hash mismatch'):
                prepare.get_archive(source, cache)
        self.assertEqual(list(cache.iterdir()), [])

    def test_reject_unsafe_output_paths(self):
        for rel in ['../escape', '/absolute', 'C:/outside', 'dir\\escape']:
            with self.subTest(rel=rel), self.assertRaises(ValueError):
                prepare.local_path(self.root, rel)

    def test_patch_input_and_context_checked(self):
        _, _, recipes, _ = self.fixture()
        recipe = recipes['lib/unit.pas']
        with self.assertRaisesRegex(RuntimeError, 'input hash mismatch'):
            prepare.apply_recipe(b'unknown version', recipe)
        recipe['edits'] = [dict(old='absent', new='replacement')]
        with self.assertRaisesRegex(RuntimeError, 'context mismatch'):
            prepare.apply_recipe(b'original', recipe)

    def test_sdk_generation_does_not_modify_installed_source(self):
        sdk = self.root/'sdk/source/rtl/win/Winapi.UIAutomation.pas'
        sdk.parent.mkdir(parents=True)
        source = b"function Example: Integer; external 'UIAutomationCore.dll' name 'UiaReturnRawElementProvider';\r\n"
        sdk.write_bytes(source)
        result = prepare.sdk_overlay(self.root/'sdk')
        self.assertIn(b"name 'UiaReturnRawElementProvider' delayed;", result)
        self.assertEqual(sdk.read_bytes(), source)


if __name__ == '__main__':
    unittest.main()
