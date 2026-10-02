#!/usr/bin/env python3
"""Reject retired recording entry points in the shipping targets."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
roots = [root / 'Apps/AnchorIOS', root / 'Apps/AnchorMac', root / 'Packages/AnchorKit/Sources']
forbidden = ('DemoHostedTasks', 'RecordingReturnDemo', 'ANCHOR_UI_TEST_RECORDING',
             'ANCHOR_SETUP_VISUAL_RECORDING', 'StoryboardPreview', 'SimulatedProcessSource',
             'Parallel efficiency 2.4', '并行效率 2.4', '"profile.icloud.just.now"',
             'ANCHOR_RETURN_REVIEW_EXPORT', '8EAB749A-9806-4D96-9577-10AA97049D4C',
             '8EAB749A-9806-4D96-9577-10AA97049D4D')
errors = []
for directory in roots:
    for path in directory.rglob('*'):
        if path.is_file() and path.suffix in ('.swift', '.xcstrings', '.json'):
            content = path.read_text()
            for token in forbidden:
                if token in content:
                    errors.append(f'{path.relative_to(root)}: {token}')
if errors:
    sys.exit('\n'.join(errors))
print('Production data boundary passed.')
