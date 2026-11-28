"""Source contract for the approved compact Mac dashboard and cycle count."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'Sources/macdir/main.swift').read_text()
RESOURCES = (ROOT / 'Sources/MacdirCore/Resources.swift').read_text()
GEO = (ROOT / 'Sources/MacdirCore/EgressLocation.swift').read_text()

class Compact111(unittest.TestCase):
    def test_real_cycle_count_never_substitutes_a_fixture(self):
        self.assertIn('batteryCycles: Int?', RESOURCES)
        self.assertIn('IORegistryEntryCreateCFProperty', RESOURCES)
        self.assertIn('AppleSmartBattery', RESOURCES)
        self.assertIn('s.batteryCycles = BatteryCycles.read()', RESOURCES)
        self.assertNotIn('model.snapshot.batteryCycles', MAIN)
        self.assertNotIn('БАТАРЕЯ · ЗАРЯД', MAIN)
        self.assertNotIn('1_227', MAIN)
        self.assertNotIn('1227', MAIN)

    def test_narrow_toolbar_and_network_control_do_not_waste_rows(self):
        self.assertIn('count: viewportWidth >= 800 ? 4 : 2', MAIN)
        self.assertIn('}.labelsHidden().frame(width: 110)', MAIN)

    def test_single_disk_card_retains_apfs_caveat_and_details(self):
        disk = MAIN.split('private var diskGauge:', 1)[1].split('private func compactToolbar(', 1)[0]
        self.assertIn('model.snapshot.diskOccupied', disk)
        self.assertIn('MetricPresentation.usedTotal(', disk)
        self.assertIn('APFS: занято в общем пуле, не сумма папок', disk)
        self.assertIn('.popover(isPresented: $model.showCapacity)', disk)
        self.assertNotIn('DiskCapacityOverview(', MAIN)

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
        self.assertIn('diskGauge', MAIN.split('private func compactResources(', 1)[1].split('private var compactNetwork:', 1)[0])
        self.assertNotIn('compactDisk', MAIN)
        self.assertNotIn('Spacer()\n     Image(systemName: model.scanning', MAIN)

if __name__ == '__main__': unittest.main()
