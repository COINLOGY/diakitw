import Foundation

private func require(_ condition: Bool, _ message: String) {
    if !condition { fatalError(message) }
}

@main struct PromptChecks {
    static func main() {
        let suite = "diakitw-prompt-checks-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        require(UpdateOfferPromptPolicy.shouldShow(version: "0.5.8", build: 58, defaults: defaults), "first background offer")
        // Cancelled checks and manual checks never mark an offer as prompted.
        require(UpdateOfferPromptPolicy.shouldShow(version: "0.5.8", build: 58, defaults: defaults), "unshown offer remains eligible")
        UpdateOfferPromptPolicy.markShown(version: "0.5.8", build: 58, defaults: defaults)
        require(!UpdateOfferPromptPolicy.shouldShow(version: "0.5.8", build: 58, defaults: defaults), "same activation dedupe")
        let restarted = UserDefaults(suiteName: suite)!
        require(!UpdateOfferPromptPolicy.shouldShow(version: "0.5.8", build: 58, defaults: restarted), "cross-process dedupe")
        require(UpdateOfferPromptPolicy.shouldShow(version: "0.5.8", build: 59, defaults: restarted), "new build eligible")
        require(UpdateOfferPromptPolicy.shouldShow(version: "0.5.9", build: 59, defaults: restarted), "new version eligible")
        UpdateOfferPromptPolicy.markShown(version: "0.5.9", build: 59, defaults: restarted)
        require(!UpdateOfferPromptPolicy.shouldShow(version: "0.5.8", build: 58, defaults: restarted), "earlier version stays deduped")
        print("PASS prompt: first offer / cancellation / activation / restart / build / version")
    }
}
