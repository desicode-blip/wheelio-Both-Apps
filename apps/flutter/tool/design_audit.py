"""Render the designed states against the owner's pinned Git reference.

Requires Flutter 3.38.6, Python, Pillow and numpy. Uses isolated sample state,
never initializes Firebase, and leaves production files/configuration untouched.
Outputs are ignored under .cache/design-audit. Not physical-device acceptance.
"""
from pathlib import Path
import io
import json
import os
import re
import shutil
import subprocess
import tempfile
import zipfile

import numpy as np
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
BASELINE = 'af036f070aa624310b97b8277bfb6aabf9d8c4cc'
OUT = ROOT / '.cache/design-audit'
TEMPLATE = Path(__file__).with_name('design_audit_capture.dart.template').read_text(encoding='utf8')
FLUTTER = os.environ.get('FLUTTER_BIN', 'flutter')


def flutter(cwd, args):
    if os.name == 'nt':
        literal = lambda value: "'" + value.replace("'", "''") + "'"
        command = '& ' + ' '.join(map(literal, [FLUTTER, *args])) + '; exit $LASTEXITCODE'
        subprocess.run(['powershell.exe', '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', command], cwd=cwd, check=True)
    else:
        subprocess.run([FLUTTER, *args], cwd=cwd, check=True)


def capture(version, base, app):
    cwd = base / 'apps/flutter' / app
    source = (cwd / 'lib/screens/gallery.dart').read_text(encoding='utf8')
    ids = list(dict.fromkeys(re.findall(r"_E\('([^']+)'", source)))
    if app == 'customer':
        ids.append('C12-tomorrow')
        opening = """
        router.setSplash(false);store.hasSeenWelcome=true;router.go(N.gallery);
        await tester.pump();await tester.pump(const Duration(milliseconds:500));drain();
        final tile=find.text(id=='C12-tomorrow'?'C12':id).last;
        await tester.ensureVisible(tile);await tester.pump(const Duration(milliseconds:100));
        await tester.tap(tile);await tester.pump();
        if(id=='C12-tomorrow'){
          await tester.pump(const Duration(milliseconds:800));
          await tester.tap(find.text('Tomorrow'));await tester.pump();
          expect(find.text('Any time of the day'),findsOneWidget);
        }
        """
    else:
        opening = """
        final entry=galleryAll.firstWhere((e)=>e.id==id);
        router.setTour(galleryAll.indexOf(entry),Lang.en);
        openGalleryEntry(entry,store,router);
        // Only this disconnected render fixture re-enables the original training
        // states. Production remains hidden under the separate owner decision.
        store.liveConfig={'training':{'enabled':true,'required':true}};store.changed();
        """
    text = TEMPLATE.replace('APP_PACKAGE', f'washkrew_{app}').replace('APP_WIDGET', 'CustomerApp' if app == 'customer' else 'CaptainApp').replace('APP_SCOPE', 'AppScope' if app == 'customer' else 'CaptainScope').replace('OPEN_CASE', opening).replace('AFTER_CASE', 'store.captainArrived();' if app == 'captain' else '').replace('CASE_IDS', ','.join(map(repr, ids)))
    target = cwd / '.dart_tool/design_audit_capture_test.dart'
    target.parent.mkdir(parents=True, exist_ok=True)
    flutter(cwd, ['pub', 'get', '--enforce-lockfile'])
    target.write_text(text, encoding='utf8')
    captures = OUT / 'captures' / version / app
    flutter(cwd, ['test', str(target), f'--dart-define=DESIGN_AUDIT_OUT={captures.as_posix()}'])
    manifest = json.loads((captures / 'manifest.json').read_text())
    failures = [entry for entry in manifest if not entry['captured'] or entry['errors']]
    if failures:
        raise RuntimeError(f'{version}/{app}: {failures}')
    return ids


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    archive = subprocess.check_output(['git', 'archive', '--format=zip', BASELINE, 'apps/flutter'], cwd=ROOT)
    source_root = Path(tempfile.mkdtemp(prefix='source-', dir=OUT))
    if not source_root.resolve().is_relative_to(OUT.resolve()):
        raise ValueError('Fixture path outside audit directory')
    reference = source_root / 'reference'
    current = source_root / 'current'
    reference.mkdir()
    with zipfile.ZipFile(io.BytesIO(archive)) as source:
        for entry in source.infolist():
            if not (reference / entry.filename).resolve().is_relative_to(reference.resolve()):
                raise ValueError('Archive path outside audit directory')
        source.extractall(reference)
    # Copy the current working files, including uncommitted fixes, never ignored
    # local secrets/builds. Both variants run away from the actual app workspaces.
    names = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z', '--', 'apps/flutter'], cwd=ROOT).decode().split('\0')
    for name in names:
        if not name or not (ROOT / name).is_file():
            continue
        target = current / name
        if not target.resolve().is_relative_to(current.resolve()):
            raise ValueError('Current source path outside audit directory')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
    # DateTime.now is used directly by the authored sample data. Freeze it only
    # in these disposable render copies so minute/date labels do not produce
    # false differences when the two Flutter processes run at different times.
    for variant in [reference, current]:
        for app in ['customer', 'captain', 'packages/washkrew_ui', 'packages/washkrew_firebase']:
            for file in (variant / 'apps/flutter' / app / 'lib').rglob('*.dart'):
                text = file.read_text(encoding='utf8')
                file.write_text(text.replace('DateTime.now()', 'DateTime(2026, 10, 28, 9, 30)'), encoding='utf8')
    rows = []
    panels = OUT / 'comparisons'
    panels.mkdir(exist_ok=True)
    for app in ['customer', 'captain']:
        old_ids = capture('reference', reference, app)
        new_ids = capture('current', current, app)
        if old_ids != new_ids:
            raise RuntimeError(f'{app}: gallery list changed; audit explicitly before updating the design lock')
        for screen in old_ids:
            old = Image.open(OUT / f'captures/reference/{app}/{screen}.png').convert('RGB')
            new = Image.open(OUT / f'captures/current/{app}/{screen}.png').convert('RGB')
            if old.size != new.size:
                raise RuntimeError(f'{app}/{screen}: dimensions changed')
            delta = np.abs(np.asarray(old, dtype=np.int16) - np.asarray(new, dtype=np.int16))
            mask = delta.max(axis=2) > 8
            y, x = np.where(mask)
            row = {'app': app, 'id': screen, 'exact': bool(not delta.any()), 'changed': int(mask.sum()), 'box': [int(x.min()), int(y.min()), int(x.max()), int(y.max())] if len(x) else None}
            # Flutter's animated offer timer has at most four antialias pixels
            # of jitter in this fixed region. No other layout region is masked.
            row['timer_only'] = app == 'captain' and 0 < row['changed'] <= 4 and all(352 <= int(v) <= 354 for v in x) and all(120 <= int(v) <= 125 for v in y)
            rows.append(row)
            if mask.any():
                panel = Image.new('RGB', (1190, 890), '#dce1e8')
                draw = ImageDraw.Draw(panel)
                for i, (label, im) in enumerate([('af036f0', old), ('current', new), ('difference', ImageChops.difference(old, new).point(lambda p: min(255, p * 4)))]):
                    draw.text((10 + i * 395, 8), f'{app}/{screen}: {label}', fill='black')
                    panel.paste(im, (5 + i * 395, 32))
                panel.save(panels / f'{app}-{screen}.png')
    (OUT / 'results.json').write_text(json.dumps({'baseline': BASELINE, 'states': rows}, indent=2))
    failures = [r for r in rows if r['changed'] and not r['timer_only']]
    print(f"{len(rows)} states: {sum(r['exact'] for r in rows)} pixel-exact, {sum(r['timer_only'] for r in rows)} timer-only, {len(failures)} need review. See {OUT}")
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
