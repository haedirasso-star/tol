#!/usr/bin/env python3
"""
TOTV+ — توقيع يدوي لهدف Runner فقط (لا يلمس مكتبات Pods):
python3 ios/ci/set_signing.py <TEAM_ID> "<PROFILE_NAME>" "<IDENTITY: Apple Distribution|Apple Development>"
"""
import sys
from pathlib import Path

team, profile, identity = sys.argv[1], sys.argv[2], sys.argv[3]
p = Path(__file__).resolve().parents[1] / 'Runner.xcodeproj' / 'project.pbxproj'
s = p.read_text(encoding='utf-8')
marker = 'PRODUCT_BUNDLE_IDENTIFIER = com.totv.plus;\n'
assert s.count(marker) == 3, 'unexpected project layout'
add = (marker +
       f'\t\t\t\tCODE_SIGN_STYLE = Manual;\n'
       f'\t\t\t\tDEVELOPMENT_TEAM = {team};\n'
       f'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profile}";\n'
       f'\t\t\t\tCODE_SIGN_IDENTITY = "{identity}";\n'
       f'\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "{identity}";\n')
s = s.replace(marker, add)
p.write_text(s, encoding='utf-8')
print(f'✓ Runner signing: team={team} profile="{profile}" identity="{identity}"')
