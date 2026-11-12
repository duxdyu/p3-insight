"""Download pinned PI dependencies and generate a local Delphi SDK overlay."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import os
import re
import shutil
import urllib.request
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load_json(name):
    return json.loads((ROOT / 'dependencies' / name).read_text('utf-8'))


def local_path(root, rel):
    path = PurePosixPath(rel)
    if (not rel or path.is_absolute() or '..' in path.parts or
            '\\' in rel or ':' in rel):
        raise ValueError('Unsafe dependency path: ' + rel)
    result = root.joinpath(*path.parts)
    if not result.resolve().is_relative_to(root.resolve()):
        raise ValueError('Dependency path escapes output: ' + rel)
    return result


def verify_vendor(folder, lock):
    for rel, digest in lock.items():
        p = local_path(folder, rel)
        if not p.is_file() or sha(p.read_bytes()) != digest:
            raise RuntimeError('Dependency mismatch: ' + rel)


def sdk_overlay(bds):
    sdk = Path(bds) / 'source/rtl/win/Winapi.UIAutomation.pas'
    if not sdk.is_file():
        raise RuntimeError('SDK source not found: ' + str(sdk) +
                           '; install Delphi 13 with RTL source from Embarcadero.')
    data = sdk.read_bytes()
    bom = data.startswith(b'\xef\xbb\xbf')
    text = data.decode('utf-8-sig')
    pattern = r"(external\s+['\"]UIAutomationCore\.dll['\"]\s+name\s+['\"]UiaReturnRawElementProvider['\"])(\s+delayed)?\s*;"
    if len(list(re.finditer(pattern, text, re.I))) != 1:
        raise RuntimeError('SDK declaration differs; inspect before adapting')
    text = re.sub(pattern, lambda m: m[1] + ' delayed;', text, flags=re.I)
    return (b'\xef\xbb\xbf' if bom else b'') + text.encode('utf-8')


def get_archive(source, cache, offline=False):
    archive = local_path(cache, source['cache_name'])
    if archive.exists():
        if sha(archive.read_bytes()) != source['sha256']:
            raise RuntimeError('Cached archive hash mismatch: ' + str(archive))
        return archive
    if offline:
        raise RuntimeError('Offline archive missing: ' + str(archive))
    if not source['url'].startswith('https://'):
        raise RuntimeError('Expected HTTPS archive URL')
    cache.mkdir(parents=True, exist_ok=True)
    partial = archive.with_name(archive.name + '.' + uuid.uuid4().hex + '.part')
    request = urllib.request.Request(source['url'], headers={'User-Agent': 'P3-Insight-dependency-preparer/1'})
    try:
        print('Downloading', source['id'], flush=True)
        with urllib.request.urlopen(request, timeout=60) as response, partial.open('xb') as output:
            total = 0
            while chunk := response.read(1024 * 1024):
                total += len(chunk)
                if total > 256 * 1024 * 1024:
                    raise RuntimeError('Unexpected archive size: ' + source['id'])
                output.write(chunk)
        if sha(partial.read_bytes()) != source['sha256']:
            raise RuntimeError('Downloaded archive hash mismatch: ' + source['id'])
        partial.replace(archive)
    finally:
        if partial.exists():
            partial.unlink()
    return archive


def apply_recipe(data, recipe):
    if sha(data) != recipe['input_sha256']:
        raise RuntimeError('Compatibility input hash mismatch')
    if recipe.get('transform') == 'cp1252-to-utf8-bom-expand-lf':
        # Preserve the validated baseline's historical encoding/line endings.
        data = b'\xef\xbb\xbf' + data.decode('cp1252').replace('\n', '\r\n').encode('utf-8')
    elif recipe.get('transform'):
        raise RuntimeError('Unknown compatibility transform')
    for edit in recipe['edits']:
        old, new = edit['old'].encode('latin1'), edit['new'].encode('latin1')
        if not old or data.count(old) != 1:
            raise RuntimeError('Compatibility edit context mismatch')
        data = data.replace(old, new)
    if sha(data) != recipe['output_sha256']:
        raise RuntimeError('Compatibility output hash mismatch')
    return data


def unpack_selected(archive, source, stage, lock):
    prefix = source['archive_prefix']
    with zipfile.ZipFile(archive) as z:
        for member in z.infolist():
            if member.is_dir() or not member.filename.startswith(prefix):
                continue
            rel = source['destination'] + '/' + member.filename[len(prefix):]
            if rel not in lock:
                continue
            target = local_path(stage, rel)
            data = z.read(member)
            if target.exists() and target.read_bytes() != data:
                raise RuntimeError('Conflicting archive entry: ' + rel)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)


def prepare_vendor(output, lock, sources=None, recipes=None, cache=None, offline=False, vendor=None):
    destination = output / 'vendor'
    # A rerun never silently replaces an existing modified dependency tree.
    if destination.exists():
        verify_vendor(destination, lock)
        print('Existing vendor matches all', len(lock), 'locked files.')
        return
    if vendor is not None:
        verify_vendor(vendor, lock)
    work = output / 'build'
    work.mkdir(parents=True, exist_ok=True)
    stage = work / ('dependency-stage-' + uuid.uuid4().hex)
    stage.mkdir()
    try:
        if vendor is not None:
            for rel in lock:
                target = local_path(stage, rel)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(local_path(vendor, rel), target)
        else:
            for source in sources:
                unpack_selected(get_archive(source, cache, offline), source, stage, lock)
            for rel, recipe in recipes.items():
                target = local_path(stage, rel)
                if 'copy_from' in recipe:
                    data = local_path(stage, recipe['copy_from']).read_bytes()
                    if sha(data) != recipe['output_sha256']:
                        raise RuntimeError('Template hash mismatch: ' + rel)
                else:
                    data = apply_recipe(target.read_bytes(), recipe)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
        verify_vendor(stage, lock)
        if destination.exists():
            raise RuntimeError('Vendor appeared during preparation; refusing replacement')
        stage.rename(destination)
        print('Prepared and verified', len(lock), 'vendor files.')
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--bds', default=os.environ.get('BDS'), help='Installed RAD Studio root')
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument('--download', action='store_true', help='Fetch fixed upstream archives and apply compatibility edits')
    mode.add_argument('--vendor', type=Path, help='Copy an existing vt/gr/lines/xml/jcl/jvcl/bm tree matching the lock')
    mode.add_argument('--sdk-only', action='store_true', help='Generate only the SDK overlay (also the default without a mode)')
    ap.add_argument('--offline', action='store_true', help='With --download, use cached ZIPs only')
    ap.add_argument('--cache', type=Path, help='Archive cache, default: OUTPUT/build/dependency-cache')
    ap.add_argument('--output', type=Path, default=ROOT, help='Output root, default: repository root; useful for isolated verification')
    args = ap.parse_args()
    if not args.bds:
        ap.error('Set BDS or pass --bds for your installed Delphi 13')
    if (args.offline or args.cache) and not args.download:
        ap.error('--offline/--cache require --download')
    overlay = sdk_overlay(args.bds)
    output = args.output.resolve()
    target = output / 'sdk-overlay/Winapi.UIAutomation.pas'
    if target.exists() and target.read_bytes() != overlay:
        raise RuntimeError('Existing SDK overlay differs; preserve/review it before regenerating: ' + str(target))
    if args.download or args.vendor:
        prepare_vendor(output, load_json('vendor-lock.json'),
                       sources=load_json('upstream-sources.json'), recipes=load_json('compatibility.json'),
                       cache=(args.cache or output/'build/dependency-cache').resolve(),
                       offline=args.offline, vendor=args.vendor)
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        target.write_bytes(overlay)
    print('SDK overlay ready; installed SDK was read only.')
    if not (args.download or args.vendor):
        print('Vendor not prepared. For the full PI group run again with --download.')


if __name__ == '__main__':
    main()
