"""Verify a production AAB before Play upload; requires Java + official bundletool.

python apps/flutter/tool/verify-android-store.py PATH.aab --bundletool PATH.jar
Uses standard libraries only; never reads private signing passwords.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ANDROID = '{http://schemas.android.com/apk/res/android}'
CERT = '68:F4:A2:E9:B1:27:02:A0:B0:54:60:C5:73:F3:CB:72:84:7E:C5:30:AF:DB:D7:0D:A2:AA:7C:AB:2B:DD:4A:8A'
ABIS = {'armeabi-v7a', 'arm64-v8a', 'x86_64'}


def elf_alignment(data):
    """Return LOAD alignments from a 64-bit little-endian Android ELF."""
    if data[:6] != b'\x7fELF\x02\x01':
        raise ValueError('Expected a 64-bit little-endian ELF')
    offset = struct.unpack_from('<Q', data, 32)[0]
    size, count = struct.unpack_from('<HH', data, 54)
    if size < 56 or offset + count * size > len(data):
        raise ValueError('Truncated ELF program table')
    return [struct.unpack_from('<Q', data, offset + i * size + 48)[0]
            for i in range(count) if struct.unpack_from('<I', data, offset + i * size)[0] == 1]


def verify(bundle, bundletool, java='java'):
    bundle = Path(bundle).resolve()
    report_file = bundle.with_suffix('.json')
    report = json.loads(report_file.read_text())
    if report.get('profile') != 'store' or report.get('nativeShrinking') is not True:
        raise ValueError('Expected production-build provenance, not an internal-test bundle')
    sha = hashlib.sha256(bundle.read_bytes()).hexdigest()
    if report['sha256'] != sha:
        raise ValueError('Bundle differs from build provenance')
    java = shutil.which(java) or java
    javabin = Path(java).parent

    def run(args):
        return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)

    run([java, '-jar', str(bundletool), 'validate', '--bundle=' + str(bundle)])
    manifest = ET.fromstring(run([java, '-jar', str(bundletool), 'dump', 'manifest', '--bundle=' + str(bundle)]))
    package = manifest.attrib['package']
    if package != report['package'] or package not in {'com.amanmaheshwari.wheelio.customer', 'com.amanmaheshwari.wheelio.captain'}:
        raise ValueError('Unexpected app/package')
    if int(manifest.attrib[ANDROID + 'versionCode']) != report['build'] or manifest.attrib[ANDROID + 'versionName'] != report['version']:
        raise ValueError('Package version differs from provenance')
    sdk = manifest.find('uses-sdk')
    if int(sdk.attrib[ANDROID + 'targetSdkVersion']) < 36:
        raise ValueError('Play release must target API 36 or later')
    if manifest.find('application').attrib.get(ANDROID + 'debuggable', 'false') != 'false':
        raise ValueError('Debuggable store release')
    if manifest.find('application').attrib.get(ANDROID + 'allowBackup') != 'false':
        raise ValueError('Private account data must not be restored from Android app backup')
    if any(p.attrib[ANDROID + 'name'] == 'android.permission.ACCESS_BACKGROUND_LOCATION' for p in manifest.findall('uses-permission')):
        raise ValueError('Unexpected background location permission')
    mapping = bundle.with_name(bundle.stem + '-mapping.txt')
    if not mapping.is_file() or mapping.stat().st_size == 0:
        raise ValueError('R8 mapping must be preserved alongside this exact bundle')
    checked = []
    with zipfile.ZipFile(bundle) as z:
        if z.testzip() is not None:
            raise ValueError('Corrupt AAB entry')
        libraries = [n for n in z.namelist() if re.fullmatch(r'base/lib/[^/]+/[^/]+\.so', n)]
        abis = {n.split('/')[2] for n in libraries}
        if abis != ABIS:
            raise ValueError('Production bundle must have three complete ABIs: ' + str(abis))
        for abi in abis:
            for lib in ('libflutter.so', 'libapp.so'):
                if f'base/lib/{abi}/{lib}' not in libraries:
                    raise ValueError('ABI advertised without Flutter engine/AOT: ' + abi)
        for name in libraries:
            if name.split('/')[2] in {'arm64-v8a', 'x86_64'}:
                alignments = elf_alignment(z.read(name))
                if not alignments or min(alignments) < 16384:
                    raise ValueError('Native library lacks 16 KB LOAD alignment: ' + name)
                checked.append(name)
        if 'BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map' not in z.namelist():
            raise ValueError('Expected R8 mapping embedded in the production AAB')
    config = run([java, '-jar', str(bundletool), 'dump', 'config', '--bundle=' + str(bundle)])
    if 'PAGE_ALIGNMENT_16K' not in config:
        raise ValueError('Bundle does not request 16 KB APK packaging alignment')
    ext = '.exe' if (javabin / 'keytool.exe').exists() else ''
    cert = run([str(javabin / ('keytool' + ext)), '-J-Duser.language=en', '-printcert', '-jarfile', str(bundle)])
    if CERT not in cert:
        raise ValueError('Unexpected upload certificate. Do not regenerate or replace the Play key')
    signature = run([str(javabin / ('jarsigner' + ext)), '-J-Duser.language=en', '-verify', str(bundle)])
    if 'jar verified.' not in signature:
        raise ValueError('JAR signature not verified')
    report['verification'] = {
        'bundletool': 'PASS', 'signature': 'PASS', 'expectedUploadCertificate': True,
        'targetSdk': int(sdk.attrib[ANDROID + 'targetSdkVersion']),
        'abis': sorted(ABIS), 'native64BitLibrariesChecked': len(checked),
        'elf16KbLoadAlignment': 'PASS', 'apkPackagingAlignment': 'PAGE_ALIGNMENT_16K',
        'r8MappingEmbedded': True,
        'limitations': 'Does not establish Play acceptance or device runtime on every architecture/16 KB device.',
    }
    report_file.write_text(json.dumps(report, indent=2) + '\n')
    return {'bundle': str(bundle), 'sha256': sha, **report['verification']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle')
    parser.add_argument('--bundletool', required=True)
    parser.add_argument('--java', default='java')
    args = parser.parse_args()
    print(json.dumps(verify(args.bundle, args.bundletool, args.java), indent=2))
