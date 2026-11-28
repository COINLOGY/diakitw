import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

let suite = "diakitw-server-profiles-\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
var store = ServerProfiles(defaults: defaults)
expect(store.profiles.isEmpty, "new fleet has no demo servers")
expect(store.selection == nil, "root selected initially")
expect(store.rows.isEmpty, "no invented metrics")
let first = try ServerProfiles.validate(name: " AI ", host: "example.org", port: "2222", login: "ops")
expect(first.name == "AI" && first.host == "example.org" && first.port == 2222, "trimmed valid domain")
let id = store.save(first)
expect(store.rows.count == 1 && store.rows[0].cpu == "Н/Д" && store.rows[0].ram == "Н/Д" && store.rows[0].swap == "Н/Д" && store.rows[0].disk == "Н/Д", "unknown metrics in root row")
expect(store.selection == id && store.selected?.name == "AI", "save selects child")
store.selection = nil
expect(store.selected == nil && store.rows.count == 1, "root restores full list")
let second = try ServerProfiles.validate(name: "Bot", host: "192.0.2.3", port: "22", login: "bot")
let other = store.save(second)
expect(store.rows.count == 2 && store.selection == other, "second child in fleet")
let edited = try ServerProfiles.validate(name: "Bot 2", host: "2001:db8::1", port: "2200", login: "admin")
expect(store.save(edited, id: other) == other && store.rows.count == 2, "edit does not duplicate profile")
expect(ServerProfiles(defaults: defaults).profiles.count == 2, "profiles persist locally")
expect(ServerProfiles(defaults: defaults).profiles[1].host == "2001:db8::1", "edited host persists")
for (host, port, login) in [("", "22", "root"), ("-bad.example", "22", "root"), ("x y", "22", "root"), ("example.org", "0", "root"), ("example.org", "65536", "root"), ("example.org", "22", "") ] {
    do { _ = try ServerProfiles.validate(name: "Valid", host: host, port: port, login: login); fatalError("accepted invalid address/port/login") }
    catch ServerProfiles.ValidationError.invalidInput { }
}
expect(store.remove(other), "selected profile deleted")
expect(store.selection == nil && store.profiles.count == 1, "removed selection returns to root")
expect(ServerProfiles(defaults: defaults).profiles.map(\.id) == [id], "removal persists without touching other profiles")
expect(!store.remove(other), "missing ID cannot delete another profile")
expect(store.remove(id) && ServerProfiles(defaults: defaults).profiles.isEmpty, "last profile can be removed")
expect(!ServerProfiles.supportsSSH, "no unimplemented connection path")
print("PASS server profiles, validation, selection, persistence, unavailable metrics/SSH")
