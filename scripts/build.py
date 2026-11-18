"""Build and package PI to build/p3-insight; optionally run offline tests."""
from pathlib import Path
import argparse
import json
import os
import runpy
import subprocess
from package_runtime import package, runtime_inputs

ROOT = Path(__file__).resolve().parents[1]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('target', choices=['app', 'tests', 'all'], nargs='?', default='all')
    ap.add_argument('--bds', default=os.environ.get('BDS'))
    ap.add_argument('--allow-existing-ide', action='store_true')
    args = ap.parse_args()
    if not args.bds:
        ap.error('Set BDS or pass --bds')
    os.environ['BDS'] = args.bds
    os.environ['ALLOW_EXISTING_IDE'] = '1' if args.allow_existing_ide else '0'
    if not (ROOT / 'sdk-overlay/Winapi.UIAutomation.pas').is_file():
        raise SystemExit('Run scripts/prepare_dependencies.py first; see dependencies/README.md.')
    if not (ROOT / 'vendor/vt/Source/VirtualTrees.pas').is_file():
        raise SystemExit('PI dependencies missing; see dependencies/README.md.')
    driver = runpy.run_path(str(ROOT / 'scripts/build_ide.py'))
    groups = {'app': ['PI'], 'tests': ['Tests'], 'all': ['PI', 'Tests']}[args.target]
    if 'PI' in groups:
        runtime_inputs(ROOT)  # Check all packaged assets before launching the IDE.
    temp = ROOT / 'build/temp'
    temp.mkdir(parents=True, exist_ok=True)
    os.environ['TEMP'] = os.environ['TMP'] = str(temp)
    for group in groups:
        code = driver['run'](group, timeout=240)
        if code:
            raise SystemExit(code)
        if group == 'PI':
            package(ROOT)
        names = {'PI': [], 'Tests': ['XMLHelperTests', 'ABILayoutTests', 'ReadinessTests']}[group]
        results = []
        for name in names:
            exe = ROOT / 'build/tests' / (name + '.exe')
            command = [str(exe)]
            if name == 'XMLHelperTests':
                command.append(str(ROOT / 'build/xml-roundtrip.xml'))
            result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=45)
            row = dict(test=exe.name, exit=result.returncode,
                       stdout=result.stdout.decode('mbcs', errors='replace'),
                       stderr=result.stderr.decode('mbcs', errors='replace'))
            results.append(row)
            print(row['stdout'])
            (ROOT / 'build' / (group + '-tests.json')).write_text(
                json.dumps(results, ensure_ascii=False, indent=2), 'utf-8')
            if result.returncode:
                raise RuntimeError('Test failed: ' + name)


if __name__ == '__main__':
    main()
