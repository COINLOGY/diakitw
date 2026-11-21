"""Source contract for the approved compact Mac dashboard and cycle count."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'Sources/macdir/main.swift').read_text()
RESOURCES = (ROOT / 'Sources/MacdirCore/Resources.swift').read_text()
GEO = (ROOT / 'Sources/MacdirCore/EgressLocation.swift').read_text()

class Compact106(unittest.TestCase):
    def test_real_cycle_count_never_substitutes_a_fixture(self):
        self.assertIn('batteryCycles: Int?', RESOURCES)
        self.assertIn('IORegistryEntryCreateCFProperty', RESOURCES)
        self.assertIn('AppleSmartBattery', RESOURCES)
        self.assertIn('s.batteryCycles = BatteryCycles.read()', RESOURCES)
        self.assertIn('model.snapshot.batteryCycles', MAIN)
        self.assertNotIn('1_227', MAIN)
        self.assertNotIn('1227', MAIN)

    def test_narrow_toolbar_and_network_control_do_not_waste_rows(self):
        self.assertIn('count: viewportWidth >= 800 ? 4 : 2', MAIN)
        self.assertIn('}.labelsHidden().frame(width: 110)', MAIN)

    def test_capacity_strip_keeps_apfs_caveat_on_hover(self):
        disk = (ROOT / 'Sources/macdir/DiskCapacityOverview.swift').read_text()
        self.assertIn('HStack(alignment: .center, spacing: 12)', disk)
        self.assertIn('Занятость файловой системы — не сумма папок', disk)
        self.assertIn('snapshot.validatedDiskFree', disk)
        self.assertIn('snapshot.diskMeasured?', disk)

    def test_compact_layout_preserves_flag_from_validated_geo_response(self):
        self.assertIn('model.egressLocation?.flag', MAIN)
        self.assertIn('Text(flag).font(.system(size: 16)).fixedSize()', MAIN)
        self.assertIn('public var flag: String?', GEO)
        self.assertIn('validCountryCode(r.country_code)', GEO)
        self.assertIn('validCountryCode(r.code)', GEO)
        self.assertIn('private var compactIdentity:', MAIN)
        self.assertIn('private func compactToolbar(', MAIN)
        self.assertIn('private func compactResources(', MAIN)
        self.assertIn('private var compactNetwork:', MAIN)
        self.assertIn('private var compactDisk:', MAIN)
        self.assertNotIn('Spacer()\n     Image(systemName: model.scanning', MAIN)

if __name__ == '__main__': unittest.main()
