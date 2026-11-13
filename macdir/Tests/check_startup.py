from pathlib import Path
import unittest

class StartupWiring(unittest.TestCase):
    def test_model_initialization_starts_root_scan(self):
        code = (Path(__file__).resolve().parents[1] / 'Sources/macdir/main.swift').read_text()
        initializer = code.split(' init() {', 1)[1].split(' deinit', 1)[0]
        self.assertIn('scan(URL(fileURLWithPath: "/"))', initializer)

    def test_listing_published_before_recursive_scan(self):
        code = (Path(__file__).resolve().parents[1] / 'Sources/macdir/main.swift').read_text()
        scan = code.split(' func scan(_ url: URL) {', 1)[1].split(' func cancel()', 1)[0]
        self.assertLess(scan.index('current = preview.root'), scan.index('MacdirCore.Scanner.scan(url, cancelled: { token.isCancelled }, progress:'))
        self.assertIn('guard !token.isCancelled else { return }', scan)

if __name__ == '__main__':
    unittest.main()
