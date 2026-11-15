"""The always-visible macOS metric row must end with egress country."""
import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
class CountryInStatus(unittest.TestCase):
 def test_status_item_subscribes_to_geo_changes(self):
  hud=(R/'Sources/macdir/ResourceHUD.swift').read_text()
  self.assertIn('model.$egressLocation',hud)
  self.assertIn('model.statusVisible = true',hud)
  self.assertIn('model.statusVisible = false',hud)
  self.assertIn('StatusTypography.title(',hud)
  self.assertIn('flag: location?.flag',hud)
 def test_geo_refresh_runs_while_menu_bar_is_visible_in_background(self):
  model=(R/'Sources/macdir/main.swift').read_text()
  self.assertIn('var statusVisible = false',model)
  self.assertIn('statusVisible == true',model)
  self.assertIn('identityVisible == true && NSApp.isActive',model)
  self.assertIn('func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }',model)
  self.assertIn('window.isReleasedWhenClosed = false',model)
  self.assertIn('if !model.statusVisible { model.identityChanged() }',model)
  refresh=model.split('let generation = self?.identityGeneration',1)[1].split('let request = Task',1)[0]
  self.assertNotIn('self?.egressLocation = nil',refresh,'Do not blink to globe during a normal refresh')
 def test_typography_reserves_fixed_trailing_flag_slot(self):
  source=(R/'Sources/macdir/StatusTypography.swift').read_text()
  self.assertIn('includingFlag: Bool',source)
  self.assertIn('flag: String?',source)
  self.assertIn('🌐',source)
 def test_swift_render_fixture_asserts_flags(self):
  fixture=(R/'Tests/status_country_flag_checks.swift').read_text()
  for marker in ('🇩🇪','🇫🇮','includingFlag: true'):
   self.assertIn(marker,fixture)
  build=(R/'build.sh').read_text()
  self.assertIn('Tests/test_country_flag_status.py',build)
  self.assertIn('Tests/status_country_flag_checks.swift',build)
if __name__=='__main__':unittest.main()
