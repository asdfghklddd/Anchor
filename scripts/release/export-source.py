#!/usr/bin/env python3
"""Export current native source, including uncommitted changes, without build data."""
import argparse
from pathlib import Path
import subprocess
import zipfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
args = parser.parse_args()
subprocess.run(['python3', str(root / 'scripts/validation/check-production-data.py')], check=True)
# Explicit source roots keep user data, caches and Git history out.
entries = ['Anchor.xcodeproj', 'Apps', 'Configuration', 'Packages/AnchorKit/Package.swift',
           'Packages/AnchorKit/Sources', 'Packages/AnchorKit/Tests', 'scripts',
           'Documentation', 'docs', '.agents/skills', 'README.md', 'DESIGN.md', 'AGENTS.md', '.gitignore', '.github/workflows/native-ci.yml']
excluded = {'.DS_Store', 'xcuserdata', '.build', '.swiftpm', '__pycache__', 'node_modules'}
args.output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(args.output, 'x', compression=zipfile.ZIP_DEFLATED) as archive:
    for entry in entries:
        base = root / entry
        paths = [base] if base.is_file() else sorted(base.rglob('*'))
        for path in paths:
            relative = path.relative_to(root)
            if not path.is_file() or path.is_symlink() or excluded.intersection(relative.parts):
                continue
            if path.suffix in {'.bak', '.xcuserstate', '.pyc', '.zip'}:
                continue
            archive.write(path, Path('Anchor') / relative)
print(args.output.resolve())
