import Foundation
import MacdirCore

func check(_ ok: @autoclosure () -> Bool, _ name: String) {
 guard ok() else { fatalError("FAIL: " + name) }; print("PASS: " + name)
}
func decode(_ extra: String = "") throws -> ServerConfig {
 try ServerConfig.decode(Data(("[{\"id\":\"fixture\",\"name\":\"Fixture\",\"target\":\"test@example.invalid\",\"role\":\"bot\"" + extra + "}]").utf8))[0]
}
for value in ["null", "0", "65536", "-1", "22.5", "true", "\"22\""] {
 check((try? decode(",\"port\":" + value)) == nil, "reject invalid JSON port " + value)
}
let legacy = try decode()
check(try! legacy.sshArguments().contains("-oBatchMode=yes"), "legacy key batch mode")
let custom = try decode(",\"port\":2222")
check(try! custom.sshArguments().contains("2222"), "custom port passed")
for text in ["", " 22", "+22", "22\n", "２２", "0", "65536"] { check((try? ServerConfig.parsePort(text)) == nil, "strict UI port") }
let password = try decode(",\"authentication\":\"password\",\"port\":2222")
let passwordArgs = try password.sshArguments()
check(passwordArgs.contains("-oBatchMode=no") && passwordArgs.contains("-oPreferredAuthentications=password") && passwordArgs.contains("-oNumberOfPasswordPrompts=1"), "password mode one bounded prompt")
check(passwordArgs.contains("-oStrictHostKeyChecking=yes") && passwordArgs.contains("-oKbdInteractiveAuthentication=no") && passwordArgs.contains("-oPubkeyAuthentication=no"), "password mode no host trust or auth fallback")
check((try? decode(",\"authentication\":\"other\"")) == nil, "unknown auth rejected")
print("Server auth configuration checks passed")
