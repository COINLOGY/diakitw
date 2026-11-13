"""Source wiring only; does not claim rendered GUI coverage."""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / 'Sources/macdir/ServerPanel.swift').read_text()

class ManagementWiring(unittest.TestCase):
    def test_explicit_confirmation_and_fields(self):
        for text in ['Добавить сервер', 'Удалить из мониторинга', 'Только из локального мониторинга', 'identityFile', 'draftTarget', '.sheet(', '.alert(']:
            self.assertIn(text, SOURCE)

    def test_stale_completions_are_guarded_before_publish(self):
        self.assertEqual(SOURCE.count('guard generations[config.id] == generation else { return }'), 2)
        self.assertIn('guard visible != value else { return }', SOURCE)
        self.assertIn('private var snapshot: ServerConfigStore.Snapshot?', SOURCE)

if __name__ == '__main__':
    unittest.main()
