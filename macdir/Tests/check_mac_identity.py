from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root / 'Sources/macdir/main.swift').read_text()
resources = (root / 'Sources/MacdirCore/Resources.swift').read_text()
server = (root / 'Sources/MacdirCore/ServerSampler.swift').read_text()
assert 'MacIdentity.internalText(snapshot.interfaceAddresses, interface: selectedInterface)' in main
assert 'MacIdentity.localComputerName()' in main and 'Task.detached(priority: .utility)' in main
identity = (root / 'Sources/MacdirCore/MacIdentity.swift').read_text()
assert 'SCDynamicStoreCopyComputerName' in identity and 'gethostname' in identity
assert 'Host.current()' not in main
transport = (root / 'Sources/macdir/GeoLookup.swift').read_text()
assert 'URLSessionConfiguration.ephemeral' in transport
assert 'https://get.geojs.io/v1/ip/geo.json' in transport
assert 'timeoutIntervalForResource = 8' in transport and 'timeoutIntervalForRequest = 8' in transport
assert 'httpCookieStorage = nil' in transport and 'urlCredentialStorage = nil' in transport
assert 'externalAddress = nil' in main and 'identityRefresh.take(now:' in main
assert 'NWPathMonitor()' in main and 'pathUpdateHandler' in main
assert 'NSApplication.didBecomeActiveNotification' in main
assert 'identityChanged()' in main and 'pathMonitor.cancel()' in main
assert main.count('identityMonitor?.cancel()') >= 2
assert 'Выход в интернет / VPN' in main
# Minimum width is now adaptive; rendered size/overlap checks live in check_layout.py.
assert 'minWidth: 800' in main and 'window.contentMinSize = NSSize(width: 800, height: 540)' in main
assert resources.count('getifaddrs(&addresses)') == 1
assert 'inet_ntop' in resources and 's.interfaceAddresses' in resources
assert 'diagnostic(' not in server and 'servers-last-diagnostic' not in server
print('PASS: Mac identity source wiring (not rendered GUI or live HTTP proof)')
server_ui = (root / 'Sources/macdir/ServerPanel.swift').read_text()
# Polling keeps running in the background by default; pausing on inactivity is
# only the explicit "no background collection" mode.
assert 'server.backgroundCollecting' in server_ui and 'setBackgroundCollecting' in server_ui, 'background collection must be a persisted setting'
assert 'setAppActive(false)' in server_ui and 'NSApplication.didResignActiveNotification' in server_ui, 'inactive pause must be wired'
assert 'continuous || self.appActive' in server_ui, 'inactive pause must apply only when background collection is off'
assert 'NSApplication.willTerminateNotification' in server_ui and server_ui.count('servers.setVisible(false)') == 1, 'server polling stops only on app termination'
assert 'beginActivity' in server_ui, 'App Nap must not stretch the sampling interval'
# 5–30 s polling must reuse an SSH master session instead of a fresh handshake.
assert 'ControlMaster=auto' in (root / 'Sources/MacdirCore/ServerSampler.swift').read_text(), 'frequent polling must reuse one SSH session'
assert 'foreground: self?.statusVisible == true || (self?.identityVisible == true && NSApp.isActive)' in main
assert 'networkRate: selectedNetwork?.received' in main
assert 'networkRate: selectedNetwork?.sent' in main
assert 'NetworkRateValue(value: networkRate' in (root / 'Sources/macdir/NeedleGauge.swift').read_text()
assert server_ui.count('NetworkRateValue(') >= 2

hud = (root / 'Sources/macdir/ResourceHUD.swift').read_text()
egress = (root / 'Sources/MacdirCore/EgressLocation.swift').read_text()
main_window = (root / 'Sources/macdir/main.swift').read_text()
assert '[labeledCountry, ip, city]' in egress, 'exit address must be part of the location line'
assert 'location.flatMap { $0.summary.isEmpty ? nil : $0.summaryWithAddress }' in hud, 'status menu must show the exit address'
assert '[$0.country, $0.ip, $0.city]' in main_window, 'window header must show the exit address too'
