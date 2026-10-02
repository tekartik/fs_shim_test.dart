#!/usr/bin/env python3
"""Regenerate pubspec_overrides.yaml for local development: every tekartik /
tekaly / festenao package reachable from this package (transitively, through
the local checkouts' own pubspecs) is mapped to its local checkout under
~/tekartik/devx/git/github.com. Missing ones are listed as comments.

    python3 tool/gen_overrides.py

The file is git ignored; CI resolves the git dependencies at their HEAD.
"""
import glob
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# packages_flutter/fs_explorer_app -> fs_shim_test.dart -> tekartik -> github.com
G = os.path.realpath(os.path.join(ROOT, '..', '..', '..', '..'))
PREFIXES = ('tekartik_', 'tekaly_', 'festenao_', 'tkcms_')
NAMED = {
    'cv': 'tekartik/cv.dart/packages/cv',
    'idb_shim': 'tekartik/idb_shim.dart/idb_shim',
    'fs_shim': 'tekartik/fs_shim.dart/fs',
    'sembast': 'tekartik/sembast.dart/sembast',
    'sembast_web': 'tekartik/sembast.dart/sembast_web',
    'dev_build': 'tekartik/dev_test.dart/dev_build',
    'dev_test': 'tekartik/dev_test.dart/dev_test',
    'process_run': 'tekartik/process_run.dart/packages/process_run',
    'synchronized': 'tekartik/synchronized.dart/synchronized',
}
FIXED = {
    'tekaly_assets': 'tekartikprj/tekaly/packages/tekaly_assets',
    'tekaly_file_picker': 'tekartikprj/tekaly/packages/file_picker',
    'tekaly_file_download_web': 'tekartikprj/tekaly/packages/file_download_web',
    'tekaly_file_download': 'tekartikprj/tekaly/flutter_packages/file_download',
    'tekaly_file_picker_flutter': 'tekartikprj/tekaly/flutter_packages/file_picker_flutter',
    'tekaly_firestore_explorer': 'tekartikprj/tekaly/flutter_packages/firestore_explorer',
    'tekaly_sdb_synced': 'tekartikprj/tekaly/packages/sdb_synced',
    'tekaly_synced_db_common': 'tekartikprj/tekaly/packages/synced_db_common',
    'tekaly_sembast_synced': 'tekartikprj/tekaly/packages/sembast_synced',
    'tekaly_firestore_synced': 'tekartikprj/tekaly/packages/firestore_synced',
    'tekaly_media_cache': 'tekartikprj/tekaly/packages/tekaly_media_cache',
    'tekaly_sdb_synced_test': 'tekartikprj/tekaly/packages/sdb_synced_test',
    'tekaly_synced_db_common_test': 'tekartikprj/tekaly/packages/synced_db_common_test',
    'tekartik_app_image_webp': 'tekartik/app_image.dart/packages/app_image_webp',
    'tekartik_file_cache': 'tekaly/playlr/packages/file_cache',
}


def dep_names(pubspec_path):
    names = set()
    try:
        text = open(pubspec_path).read()
    except OSError:
        return names
    section = None
    for line in text.split('\n'):
        m = re.match(r'^(dependencies|dev_dependencies|dependency_overrides):', line)
        if m:
            section = m.group(1)
            continue
        if re.match(r'^\S', line):
            section = None
            continue
        if section in ('dependencies', 'dev_dependencies'):
            m = re.match(r'^  ([a-z0-9_]+):', line)
            if m:
                names.add(m.group(1))
    return names


def has_pubspec(path):
    return path is not None and os.path.isfile(os.path.join(path, 'pubspec.yaml'))


def local_path(name):
    if name in FIXED:
        p = os.path.join(G, FIXED[name])
        return p if has_pubspec(p) else None
    if name in NAMED:
        p = os.path.join(G, NAMED[name])
        return p if has_pubspec(p) else None
    if not name.startswith(PREFIXES):
        return None
    try:
        out = subprocess.run(
            ['tkpub', 'config', 'get-local-path', name],
            capture_output=True, text=True, timeout=20,
        ).stdout.strip().split('\n')[0]
    except Exception:
        out = ''
    if out and has_pubspec(out):
        return out
    # Fallback: search the git folder for a pubspec with that name.
    for pubspec in glob.glob(os.path.join(G, '*', '*', '**', 'pubspec.yaml'), recursive=True):
        if '/.dart_tool/' in pubspec or '/build/' in pubspec:
            continue
        try:
            first = open(pubspec).readline().strip()
        except OSError:
            continue
        if first == f'name: {name}':
            return os.path.dirname(pubspec)
    return None


members = [os.path.join(ROOT, 'pubspec.yaml')]
member_names = {open(m).readline().strip().replace('name: ', '') for m in members}

todo = set()
for m in members:
    todo |= dep_names(m)
todo = {n for n in todo if n not in member_names}
resolved = {}
missing = set()
seen = set()
while todo:
    name = todo.pop()
    if name in seen:
        continue
    seen.add(name)
    if not (name.startswith(PREFIXES) or name in NAMED or name in FIXED):
        continue
    p = local_path(name)
    if p is None:
        if name.startswith(PREFIXES):
            missing.add(name)
        continue
    resolved[name] = p
    for dep in dep_names(os.path.join(p, 'pubspec.yaml')):
        if dep not in seen and dep not in member_names:
            todo.add(dep)

lines = ['dependency_overrides:']
for name in sorted(resolved):
    lines.append(f'  {name}:')
    lines.append(f'    path: {os.path.relpath(resolved[name], ROOT)}')
for name in sorted(missing):
    lines.append(f'  # MISSING {name}')
open(os.path.join(ROOT, 'pubspec_overrides.yaml'), 'w').write('\n'.join(lines) + '\n')
print(f'pubspec_overrides.yaml: {len(resolved)} overrides, {len(missing)} missing {sorted(missing)}')
