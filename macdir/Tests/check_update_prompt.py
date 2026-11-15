"""Source-level wiring gate; Swift policy runtime checks run in build.sh on macOS CI."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class PromptWiring(unittest.TestCase):
    def test_background_offer_is_actionable_and_nonactivating(self):
        menu = (ROOT / 'Sources/macdir/UpdateMenu.swift').read_text()
        self.assertIn('checker.$offer.sink', menu)
        self.assertIn('NSHostingView(rootView: UpdateOfferPrompt(', menu)
        self.assertIn('panel.orderFront(nil)', menu)
        self.assertIn('Button("Подробнее", action: details)', menu)
        self.assertIn('Button("Позже", action: later)', menu)
        self.assertIn('show()', menu)
        self.assertIn('NSApp.isActive', menu)
        self.assertIn('window?.isVisible != true', menu)
        self.assertIn('checker.check()', menu)
        self.assertIn('Button("Скачать в браузере") { NSWorkspace.shared.open(offer.url) }', menu)
        self.assertNotIn('NSWorkspace.shared.open(offer.url)', menu.split('private struct UpdateOfferPrompt:', 1)[1].split('private struct UpdatePane:', 1)[0])

    def test_prompt_lifecycle_has_dedupe_and_cancellation_guards(self):
        menu = (ROOT / 'Sources/macdir/UpdateMenu.swift').read_text()
        policy = (ROOT / 'Sources/macdir/UpdateOfferPromptPolicy.swift').read_text()
        self.assertIn('UpdateOfferPromptPolicy.shouldShow', menu)
        self.assertIn('UpdateOfferPromptPolicy.markShown', menu)
        self.assertIn('prompt?.close()', menu)
        self.assertIn('checker.cancel()', menu)
        self.assertIn('diakitw.update.prompt.', policy)
        lifecycle = (ROOT / 'Tests/update_checks.swift').read_text()
        self.assertIn('fresh launch rechecks within 60s / 24h', lifecycle)
        self.assertIn('late aborted result rejected', lifecycle)
        self.assertIn('hidden cancels', lifecycle)
        prompt_checks = (ROOT / 'Tests/update_prompt_checks.swift').read_text()
        self.assertIn('cross-process dedupe', prompt_checks)
        self.assertIn('unshown offer remains eligible', prompt_checks)

    def test_ci_runs_policy_checks(self):
        build = (ROOT / 'build.sh').read_text()
        self.assertIn('Tests/update_prompt_checks.swift', build)
        self.assertIn('Tests/check_update_prompt.py', build)

if __name__ == '__main__': unittest.main()
