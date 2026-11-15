import Foundation

// A notification is recorded only after it is displayed, never for a cancelled fetch
// or an offer viewed through the manual updates window. Channel changes share the key.
enum UpdateOfferPromptPolicy {
    private static func key(version: String, build: Int) -> String {
        "diakitw.update.prompt.\(version).\(build)"
    }

    static func shouldShow(version: String, build: Int, defaults: UserDefaults) -> Bool {
        !defaults.bool(forKey: key(version: version, build: build))
    }

    static func markShown(version: String, build: Int, defaults: UserDefaults) {
        defaults.set(true, forKey: key(version: version, build: build))
    }
}
