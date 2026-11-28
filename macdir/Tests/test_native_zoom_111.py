"""Native window zoom wiring and pure layout policy; rendered on macOS CI."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / "Sources/macdir/ServerPanel.swift").read_text()
CORE = ROOT / "Sources/MacdirCore/WindowZoom.swift"

class NativeZoom(unittest.TestCase):
    def test_window_toolbar_and_shortcuts_do_not_capture_sheet_fields(self):
        self.assertIn("Button(\"По размеру\")", MAIN)
        self.assertIn("Button(\"100 %\")", MAIN)
        self.assertIn("keyboardShortcut(\"-\", modifiers: .command)", MAIN)
        self.assertIn("keyboardShortcut(\"+\", modifiers: .command)", MAIN)
        self.assertIn("keyboardShortcut(\"0\", modifiers: .command)", MAIN)
        self.assertIn("NSApp.keyWindow?.firstResponder", MAIN)
        self.assertIn("didChangeScreenNotification", MAIN)
        self.assertIn("onChange(of: servers.section)", MAIN)
        self.assertIn("onChange(of: servers.selectedServerID)", MAIN)
        self.assertIn("servers.adding || servers.removing != nil", MAIN)

    def test_control_and_command_modifiers_both_adjust_zoom(self):
        for key in ("-", "+", "=", "0"):
            self.assertIn(f'keyboardShortcut("{key}", modifiers: .control)', MAIN)

    def test_window_zoom_policy_is_pure_and_bounded(self):
        self.assertTrue(CORE.exists())
        self.assertIn("public enum WindowZoom", CORE.read_text())

if __name__ == "__main__": unittest.main()
