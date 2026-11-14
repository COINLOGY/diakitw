"""Source wiring + numeric contract model. Swift execution is an Apple-runner gate."""
from pathlib import Path
import itertools
import json
import math
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASELINE = {e['path']: e['source'] for e in json.loads((ROOT/'Tests/fixtures/expressive-v4-052-baseline.json').read_text()) if e['start'] is None}
SOURCE = (ROOT/'Sources/MacdirCore/StatusPresentation.swift').read_text()

class MenuSpaces(unittest.TestCase):
    def test_numeric_field_padding_contract(self):
        body = SOURCE.split('private static func field(',1)[1].split('public static func rate',1)[0]
        padding = re.search(r'String\(repeating: "(.)", count: width - result.count\)',body)[1]
        self.assertEqual(padding, ' ', 'menu only: replace zeros with spaces')
        self.assertIn('?? 0', body)
        self.assertIn('value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }', body)
        self.assertIn('if result.count > width { return "+++.+" }',body)
        self.assertIn('Locale(identifier: "en_US_POSIX")',body)
        for value,expected in [(7.3,'  7.3'),(0,'  0.0'),(100,'100.0'),(12.4,' 12.4'),
                               (None,'  0.0'),(-1,'  0.0'),(math.nan,'  0.0'),(math.inf,'  0.0'),
                               (999.94,'999.9'),(1000,'+++.+')]:
            valid = value if value is not None and math.isfinite(value) and value>=0 else 0
            raw = format(valid,'.1f')
            result = '+++.+' if len(raw)>5 else padding*(5-len(raw))+raw
            self.assertEqual(result,expected)
            self.assertEqual(len(result),5)
            self.assertEqual(result.index('.'),3)

    def test_network_transform_only_removes_two_leading_zeros(self):
        body = SOURCE.split('public static func rate(',1)[1].split('public static func segments',1)[0]
        self.assertIn('let compact = NetworkPresentation(value).compact',body)
        self.assertIn('compact.prefix(2).prefix(while: { $0 == "0" }).count',body)
        self.assertIn('String(repeating: " ", count: padding) + String(compact.dropFirst(padding))',body)
        for old,new in [('007.3K','  7.3K'),('000.0K','  0.0K'),('100.0K','100.0K'),
                        ('001.0M','  1.0M'),('999.9K','999.9K'),('+++.+M','+++.+M')]:
            padding = len(old[:2])-len(old[:2].lstrip('0'))
            self.assertEqual(' '*padding+old[padding:],new)
            self.assertEqual(len(new),6)
            self.assertEqual(new.index('.'),3)
        # Existing promotion, rounding, units and unknown policy are untouched.
        for path in ['Sources/MacdirCore/NetworkPresentation.swift',
                     'Sources/MacdirCore/MetricPresentation.swift']:
            self.assertEqual((ROOT/path).read_text(),BASELINE['macdir/'+path],path)

    def test_monospaced_width_and_visibility_wiring(self):
        typography=(ROOT/'Sources/macdir/StatusTypography.swift').read_text()
        self.assertIn('NSFont.monospacedSystemFont(ofSize: 13',typography)
        self.assertIn('String(field.dropLast()) : field',typography)
        self.assertIn('String(field.suffix(1))',typography)
        update=(ROOT/'Sources/macdir/ResourceHUD.swift').read_text().split('private func update(',1)[1]
        self.assertIn('выравнивание пробелами',update)
        self.assertIn('серые нули: нет замера · +: переполнение',update)
        self.assertNotIn('StatusTypography.width',update)
        self.assertNotIn('item?.length',update)
        variants=[['  7.3%','  0.0%','  1.0G','100.0%','  0.0K↓','999.9M↑'],
                  ['100.0%','+++.+G','+++.+G','  0.0G','+++.+M↓','  1.0K↑']]
        for visible in itertools.product([False,True],repeat=6):
            widths=[len(' '.join(v[i] for i,show in enumerate(visible) if show)) for v in variants]
            self.assertEqual(widths[0],widths[1])

if __name__ == '__main__':
    unittest.main()
