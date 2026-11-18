"""Assemble the 18-file runtime folder from verified local build outputs/assets."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BINARIES = {
    'p3insight.dll': 'p3insight.dll',
    'PI模式启动游戏.exe': 'PIProductionLauncher.exe',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local_path(root, name):
    rel = PurePosixPath(name)
    if rel.is_absolute() or '..' in rel.parts or '\\' in name or ':' in name:
        raise RuntimeError('Invalid package path: ' + name)
    path = root / name
    if not path.resolve().is_relative_to(root.resolve()):
        raise RuntimeError('Package path escapes root: ' + name)
    return path


def runtime_inputs(root):
    manifest = json.loads((root / 'runtime/manifest.json').read_text('utf-8'))
    inputs = {}
    for row in manifest['files']:
        name = row['target']
        local_path(root, name)
        if name in inputs or name in BINARIES:
            raise RuntimeError('Duplicate package target: ' + name)
        source = local_path(root, row['source'])
        if not source.is_file() or sha(source) != row['sha256']:
            raise RuntimeError('Runtime asset missing or changed: ' + row['source'])
        inputs[name] = (source, row['sha256'])
    return inputs


def package(root=ROOT):
    inputs = runtime_inputs(root)
    receipt = json.loads((root / 'build/logs/PI-build-result.json').read_text('utf-8'))
    if not receipt.get('success'):
        raise RuntimeError('PI build did not succeed')
    outputs = {Path(row['path']).resolve(): row['sha256'] for row in receipt['outputs']}
    for target, name in BINARIES.items():
        source = root / 'build/compiled/p3-insight' / name
        expected = outputs.get(source.resolve())
        if not expected or not source.is_file() or sha(source) != expected:
            raise RuntimeError('Build output missing or changed: ' + name)
        inputs[target] = (source, expected)

    output = root / 'build/p3-insight'
    # Never remove unknown user files to force the output to match the manifest.
    if output.exists():
        extras = {p.relative_to(output).as_posix()
                  for p in output.rglob('*') if p.is_file()} - inputs.keys()
        if extras:
            raise RuntimeError('Unexpected files in package output: ' + ', '.join(sorted(extras)))
    with tempfile.TemporaryDirectory(prefix='package-stage-', dir=root / 'build') as tmp:
        stage = Path(tmp)
        for name, (source, expected) in inputs.items():
            dest = local_path(stage, name)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
            if sha(dest) != expected:
                raise RuntimeError('Package copy verification failed: ' + name)
        for name in inputs:
            dest = local_path(output, name)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(stage / name, dest)
    files = {p.relative_to(output).as_posix(): sha(p)
             for p in output.rglob('*') if p.is_file()}
    if files != {name: expected for name, (_, expected) in inputs.items()}:
        raise RuntimeError('Final package verification failed')
    logs = root / 'build/logs'
    logs.mkdir(parents=True, exist_ok=True)
    (logs / 'package-result.json').write_text(json.dumps(
        dict(output=str(output), files=files, success=True),
        ensure_ascii=False, indent=2) + '\n', 'utf-8')
    print(f'Package verified: {len(files)} files -> {output}')
    return output


if __name__ == '__main__':
    package()
