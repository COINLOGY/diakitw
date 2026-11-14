"""Mac-only source/numeric gates, NOT native compile or render acceptance."""
import ast
import json
import math
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASELINE = json.loads((Path(__file__).parent/'fixtures/expressive-v4-052-baseline.json').read_text())
MAC = 'macdir/Sources/MacdirCore/GaugeScale.swift'
ANDROID = 'diakitw-android/app/src/main/java/app/diakitw/Gauge.java'
DESKTOP = 'diakitw-desktop/app/renderer.js'
EXPECTED = [(-99, 0), (0, -10), (21, -4), (21, 4), (0, 10)]

def text(path):
    return (ROOT / path).read_text()

def points(path):
    source = text(path)
    if path == MAC:
        literal = re.search(r'let vertices: \[\(Double, Double\)\] = (\[\(-99.*?\])', source)[1]
    elif path == ANDROID:
        literal = re.search(r'double\[\]\[\] p=(.*?);', source)[1].replace('{', '[').replace('}', ']')
    else:
        literal = re.search(r'of (\[\[-99.*?\])\.entries', source)[1]
    return [tuple(p) for p in ast.literal_eval(literal)]

class ExpressiveGeometry(unittest.TestCase):
    def test_exact_polygon_and_full_sweep(self):
        for path in [MAC]:
            with self.subTest(path=path):
                p = points(path)
                self.assertEqual(p, EXPECTED)
                # Exact flat tail and unchanged tip; every edge stays inside the
                # old maximum radial sweep, despite the wider triangle base.
                self.assertEqual(p[2][0], p[3][0])
                for radius in [18, 32, 38, 60, 114, 220]:
                    for step in range(101):
                        a = step / 100 * math.pi
                        scale = max(0, radius-16)/99 if path == MAC else radius/114
                        rotated = [((x*math.cos(a)-y*math.sin(a))*scale,
                                    (x*math.sin(a)+y*math.cos(a))*scale) for x,y in p]
                        self.assertAlmostEqual(math.hypot(*rotated[0]),99*scale)
                        for x,y in rotated:
                            self.assertLessEqual(math.hypot(x,y),99*scale+1e-9)
                            self.assertLessEqual(y,math.hypot(21,4)*scale+1e-9)
                        if path == MAC:
                            self.assertLessEqual(99*scale, radius-13-3+1e-9)
                        elif path == ANDROID:
                            self.assertLess(99*scale,103*scale)

    def test_native_readability_and_inset_hub_wiring(self):
        mac = text('macdir/Sources/macdir/NeedleGauge.swift')
        for token in ['StrokeStyle(lineWidth: 8 * 7 / 9',
                      'i % 5 == 0 ? 1.5 : 1',
                      '.primary.opacity(i % 5 == 0 ? 0.85 : 0.5)',
                      'Circle().fill(Color(red: 0.078, green: 0.102, blue: 0.129))',
                      '.overlay(Circle().strokeBorder(color(fraction), lineWidth: 1.5))',
                      '.frame(width: 8, height: 8).position(center)',
                      'size: 10, weight: .semibold, design: .monospaced']:
            self.assertIn(token, mac)
        self.assertIn('fraction.isFinite, (0...1).contains(fraction)', mac)
        self.assertIn('neutral ? directionColor : gaugeColor(f, battery: battery)', mac)

    def test_layout_expressions_unchanged_from_052(self):
        for entry in BASELINE:
            path, start, end = entry['path'], entry['start'], entry['end']
            current = text(path)
            if start: current = current.split(start,1)[1]
            if end: current = current.split(end,1)[0]
            self.assertEqual(current, entry['source'], path)

if __name__ == '__main__':
    unittest.main()
