#!/usr/bin/env python3
"""Sign a release ZIP and generate the signed Sparkle feed. Private key stays in Keychain."""
import argparse
import plistlib
import subprocess
from datetime import datetime, timezone
from email.utils import format_datetime
from pathlib import Path
from urllib.parse import urlparse
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / '.build/artifacts/sparkle/Sparkle/bin'
NS = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', NS)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
parser.add_argument('--url', required=True, help='Final public HTTPS URL of this ZIP')
parser.add_argument('--output', type=Path, default=ROOT / 'appcast.xml')
parser.add_argument('--account', default='community.blinkwell.updates')
parser.add_argument('--allow-localhost-testing', action='store_true')
args = parser.parse_args()
url = urlparse(args.url)
if url.scheme != 'https' and not (args.allow_localhost_testing and url.scheme == 'http' and url.hostname == '127.0.0.1'):
    parser.error('HTTPS required; loopback HTTP is allowed only for isolated testing')
with zipfile.ZipFile(args.archive) as archive:
    paths = [name for name in archive.namelist() if name.endswith('.app/Contents/Info.plist') and name.count('/') == 2]
    if len(paths) != 1:
        parser.error('ZIP must contain exactly one top-level application')
    info = plistlib.loads(archive.read(paths[0]))
public_key = subprocess.check_output([str(TOOLS / 'generate_keys'), '--account', args.account, '-p'], text=True).strip()
if public_key != info.get('SUPublicEDKey'):
    parser.error('Keychain public key differs from the app public key')
signer = [str(TOOLS / 'sign_update'), '--account', args.account]
signature = subprocess.check_output(signer + ['-p', str(args.archive.resolve())], text=True).strip()
subprocess.run(signer + ['--verify', str(args.archive.resolve()), signature], check=True)
rss = ET.Element('rss', version='2.0')
channel = ET.SubElement(rss, 'channel')
ET.SubElement(channel, 'title').text = 'Blinkwell updates'
ET.SubElement(channel, 'link').text = 'https://github.com/Kr1st10/Blinkwell'
item = ET.SubElement(channel, 'item')
ET.SubElement(item, 'title').text = 'Blinkwell ' + info['CFBundleShortVersionString']
ET.SubElement(item, 'pubDate').text = format_datetime(datetime.now(timezone.utc))
ET.SubElement(item, f'{{{NS}}}minimumSystemVersion').text = info['LSMinimumSystemVersion']
ET.SubElement(item, 'description').text = 'Новая версия Blinkwell. Перед перезапуском статистика сохраняется. Подробности изменений — на странице релиза GitHub.'
ET.SubElement(item, 'enclosure', {
    'url': args.url,
    'length': str(args.archive.stat().st_size),
    'type': 'application/octet-stream',
    f'{{{NS}}}version': info['CFBundleVersion'],
    f'{{{NS}}}shortVersionString': info['CFBundleShortVersionString'],
    f'{{{NS}}}edSignature': signature,
})
ET.indent(rss)
args.output.parent.mkdir(parents=True, exist_ok=True)
ET.ElementTree(rss).write(args.output, encoding='utf-8', xml_declaration=True)
subprocess.run(signer + [str(args.output.resolve())], check=True)
subprocess.run(signer + ['--verify', str(args.output.resolve())], check=True)
print(f'Signed feed: {args.output}')
