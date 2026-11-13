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
assert 'Внешний (выход в интернет)' in main and 'VPN' in main
# Minimum width is now adaptive; rendered size/overlap checks live in check_layout.py.
assert 'minWidth: 800' in main and 'window.contentMinSize = NSSize(width: 800, height: 540)' in main
assert resources.count('getifaddrs(&addresses)') == 1
assert 'inet_ntop' in resources and 's.interfaceAddresses' in resources
assert 'diagnostic(' not in server and 'servers-last-diagnostic' not in server
print('PASS: Mac identity source wiring (not rendered GUI or live HTTP proof)')
server_ui = (root / 'Sources/macdir/ServerPanel.swift').read_text()
assert 'NSApplication.didResignActiveNotification' in server_ui and 'NSApp.isActive' in server_ui, 'server polling must stop when app inactive'
assert 'foreground: self?.identityVisible == true && NSApp.isActive' in main
assert main.count('NetworkRateValue(') >= 2
assert server_ui.count('NetworkRateValue(') >= 2
assert 'networkRate: selectedNetwork?.received' in main
