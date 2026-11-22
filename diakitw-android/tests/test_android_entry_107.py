"""The offline native probe must find the visible entry in the accessibility tree."""
import unittest
from pathlib import Path

class EntryProbeContract(unittest.TestCase):
    def test_click_uses_node_tree_not_text_search(self):
        source = (Path(__file__).resolve().parents[1] / 'app/src/androidTest/java/app/diakitw/EntryProbe.java').read_text()
        self.assertNotIn('findAccessibilityNodeInfosByText("IP / карта")', source)
        self.assertIn('getRootInActiveWindow()', source)
        self.assertIn('getChildCount()', source)
        self.assertIn('n.performAction(AccessibilityNodeInfo.ACTION_CLICK)', source)

if __name__ == '__main__': unittest.main()
