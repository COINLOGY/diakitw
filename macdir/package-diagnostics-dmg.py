#!/usr/bin/env python3
"""Package already-tested diakitw binaries; no work on import, no overwrite/resume."""
import hashlib
import json
import os
import plistlib
import shutil
import subprocess
import tempfile
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VERSION = '1.0.3'
BUILD = '103'
NAME = 'diakitw'
README = 'README-diakitw-1.0.3-RU.txt'


def artifact_paths(root, arch, mode="signed"):
    if arch not in ('arm64', 'x86_64'):
        raise ValueError('Unsupported architecture')
    suffix = '-unsigned' if mode == 'adhoc' else ''
    output = root / f'dist/{NAME}-{VERSION}{suffix}-{arch}'
    return {'output': output, 'app': output / 'diakitw.app',
            'stage': output / 'dmg-content',
            'dmg': root / f'dist/{NAME}-{VERSION}-macos{suffix}-{arch}.dmg'}


def require_absent(path):
    if path.exists() or path.is_symlink():
        raise FileExistsError(f'Refusing existing artifact: {path}')


def run(*args):
    p = subprocess.run([str(x) for x in args], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    print('$', ' '.join(map(str, args)), '\n',
          p.stdout.decode(errors='replace') + p.stderr.decode(errors='replace'), flush=True)
    if p.returncode:
        raise RuntimeError(f'exit {p.returncode}')
    return p.stdout


def verify_developer_id(path):
    result = subprocess.run(['codesign', '-dv', '--verbose=4', str(path)],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    details = result.stdout + result.stderr
    flags = next((line for line in details.splitlines() if line.startswith('CodeDirectory ') or line.startswith('flags=')), '')
    if result.returncode or 'Authority=Developer ID Application:' not in details or 'runtime' not in flags:
        raise RuntimeError(f'Not a hardened Developer ID signature: {path}')


def signing_mode():
    mode = os.environ.get('MACDIR_SIGNING_MODE', 'signed')
    if mode not in ('signed', 'adhoc') or (mode == 'adhoc' and os.environ.get('GITHUB_ACTIONS') != 'true'):
        raise RuntimeError('Invalid signing mode; ad-hoc candidates require GitHub Actions')
    return mode


def preflight(mode):
    run('bash', ROOT / 'sign-and-notarize.sh', 'adhoc-preflight' if mode == 'adhoc' else 'preflight')


def sign_target(mode, target):
    run('bash', ROOT / 'sign-and-notarize.sh', 'adhoc-sign' if mode == 'adhoc' else 'sign', target)


def finish_dmg(mode, dmg):
    if mode == 'signed':
        run('bash', ROOT / 'sign-and-notarize.sh', 'notarize', dmg)


def signature_evidence(mode):
    return {'signing': 'ad-hoc' if mode == 'adhoc' else 'Developer ID',
            'developer_id_signature_verified': mode == 'signed',
            'notarized_and_stapled': mode == 'signed',
            'gatekeeper_accepted': False}


def verify_signature(mode, path):
    run('codesign', '--verify', '--strict', path)
    if mode == 'signed':
        verify_developer_id(path)
    else:
        result = subprocess.run(['codesign', '-dv', '--verbose=4', str(path)],
                                capture_output=True, text=True)
        if result.returncode or 'Signature=adhoc' not in result.stdout + result.stderr:
            raise RuntimeError(f'Expected ad-hoc signature: {path}')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


@contextmanager
def read_only_mount(dmg):
    tmp = Path(tempfile.mkdtemp(prefix='diakitw-dmg-check-', dir=os.environ['TMPDIR']))
    mount = tmp / 'mount'
    mount.mkdir()
    data = run('hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', mount, '-plist', dmg)
    try:
        attached = plistlib.loads(data)
        assert any(x.get('mount-point') == str(mount) for x in attached['system-entities'])
        assert os.statvfs(mount).f_flag & os.ST_RDONLY
        yield mount
    finally:
        # Never recurse into a mount, including on parse/detach failure.
        run('hdiutil', 'detach', mount)
        mount.rmdir()
        tmp.rmdir()


def main():
    os.environ.setdefault('TMPDIR', str(Path.home() / '.cache/diakitw/scratch'))
    mode = signing_mode()
    evidence = ROOT / f'evidence/diakitw-{VERSION}'
    # Preflight BOTH architectures before writing anything; old releases remain untouched.
    for arch in ('arm64', 'x86_64'):
        paths = artifact_paths(ROOT, arch, mode)
        require_absent(paths['dmg'])
        require_absent(paths['stage'])
        if arch == 'x86_64':
            require_absent(paths['output'])
    require_absent(evidence / 'distribution-manifest.json')
    preflight(mode)
    records = []
    for arch in ('arm64', 'x86_64'):
        paths = artifact_paths(ROOT, arch, mode)
        app, stage, dmg = paths['app'], paths['stage'], paths['dmg']
        if arch == 'x86_64':
            (app / 'Contents/MacOS').mkdir(parents=True)
            (app / 'Contents/Resources').mkdir()
            intel_bins = ROOT / '.build-diakitw-intel/out/Products/Release'
            if not (intel_bins / 'macdir').is_file():
                intel_bins = ROOT / '.build-diakitw-intel/x86_64-apple-macosx/release'
            for name in ('macdir', 'DiagnosticWorker', 'ServerAskpass'):
                shutil.copy2(intel_bins / name,
                             app / 'Contents/MacOS' / name)
            shutil.copy2(ROOT / 'Info.plist', app / 'Contents/Info.plist')
            for name in ('macdir.icns', 'server_probe.py'):
                shutil.copy2(ROOT / 'assets' / name, app / 'Contents/Resources' / name)
            run('strip', '-S', *[app / 'Contents/MacOS' / n for n in ('macdir', 'DiagnosticWorker', 'ServerAskpass')])
            run('python3', ROOT / 'Tests/check_binary_privacy.py', app)
            sign_target(mode, app / 'Contents/MacOS/DiagnosticWorker')
            (app / 'Contents/MacOS/ServerAskpass').chmod(0o755)
            sign_target(mode, app / 'Contents/MacOS/ServerAskpass')
            sign_target(mode, app)
        run('codesign', '--verify', '--deep', '--strict', app)
        verify_signature(mode, app)
        run('python3', ROOT / 'Tests/check_binary_privacy.py', app)
        stage.mkdir()
        run('ditto', app, stage / 'diakitw.app')
        shutil.copy2(ROOT / 'assets' / README, stage / README)
        (stage / 'Applications').symlink_to('/Applications')
        run('hdiutil', 'create', '-volname', f'{NAME} {VERSION} {arch}',
            '-srcfolder', stage, '-format', 'UDZO', '-fs', 'HFS+', dmg)
        run('hdiutil', 'verify', dmg)
        finish_dmg(mode, dmg)
        with read_only_mount(dmg) as mount:
            mounted = mount / 'diakitw.app'
            assert {p.name for p in mount.iterdir()} >= {'diakitw.app', README, 'Applications'}
            assert (mount / 'Applications').is_symlink() and os.readlink(mount / 'Applications') == '/Applications'
            assert sha(mount / README) == sha(ROOT / 'assets' / README)
            run('codesign', '--verify', '--deep', '--strict', mounted)
            verify_signature(mode, mounted)
            for name in ('macdir', 'DiagnosticWorker', 'ServerAskpass'):
                binary = mounted / 'Contents/MacOS' / name
                assert run('lipo', '-archs', binary).decode().strip() == arch
                run('file', binary)
                run('xcrun', 'vtool', '-show-build', binary)
                run('codesign', '--verify', '--strict', binary)
                verify_signature(mode, binary)
                assert sha(binary) == sha(app / 'Contents/MacOS' / name)
            for name in ('macdir.icns', 'server_probe.py'):
                assert sha(mounted / 'Contents/Resources' / name) == sha(ROOT / 'assets' / name)
            plist = plistlib.loads((mounted / 'Contents/Info.plist').read_bytes())
            assert plist == plistlib.loads((ROOT / 'Info.plist').read_bytes())
            assert plist['CFBundleShortVersionString'] == VERSION and plist['CFBundleVersion'] == BUILD
            assert plist['CFBundleName'] == NAME and plist['CFBundleDisplayName'] == NAME
            assert plist['CFBundleIdentifier'] == 'local.emcx.macdir'
            assert plist['CFBundleExecutable'] == 'macdir' and plist['LSMinimumSystemVersion'] == '14.0'
            expected = {'Contents/Info.plist', 'Contents/MacOS/macdir', 'Contents/MacOS/DiagnosticWorker',
                        'Contents/MacOS/ServerAskpass', 'Contents/Resources/macdir.icns',
                        'Contents/Resources/server_probe.py', 'Contents/_CodeSignature/CodeResources'}
            assert {str(p.relative_to(mounted)) for p in mounted.rglob('*') if p.is_file()} == expected
            assert not any(p.is_symlink() for p in mounted.rglob('*'))
            records.append({'arch': arch, 'dmg': str(dmg), 'sha256': sha(dmg), 'bytes': dmg.stat().st_size,
                            'app_sha256': sha(mounted / 'Contents/MacOS/macdir'),
                            'worker_sha256': sha(mounted / 'Contents/MacOS/DiagnosticWorker'),
                            'askpass_sha256': sha(mounted / 'Contents/MacOS/ServerAskpass'),
                            'read_only_mount_verified': True, **signature_evidence(mode)})
    evidence.mkdir(parents=True, exist_ok=True)
    with (evidence / 'distribution-manifest.json').open('x') as f:
        f.write(json.dumps(records, indent=2) + '\n')
    print(json.dumps(records, indent=2))


if __name__ == '__main__':
    main()
