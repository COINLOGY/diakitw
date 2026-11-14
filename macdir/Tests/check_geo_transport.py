"""Transport fixture: only inject URLProtocol into an unshipped source copy."""
from pathlib import Path
import os, subprocess
r=Path(__file__).resolve().parents[1]
s=Path(os.environ['TMPDIR'])/'diakitw-geo-transport'
s.mkdir(exist_ok=True)
text=(r/'Sources/macdir/GeoLookup.swift').read_text()
text=text.replace('let configuration = URLSessionConfiguration.ephemeral', 'let configuration = URLSessionConfiguration.ephemeral\n  configuration.protocolClasses = [MockGeoProtocol.self]')
f=s/'GeoLookup.swift'; f.write_text(text.replace('import MacdirCore\n',''))
t=s/'checks.swift'; t.write_text((r/'Tests/geo_transport_checks.swift').read_text().replace('import MacdirCore\n',''))
exe=r/'evidence/diakitw-0.5.4/transport-checks'
subprocess.run(['swiftc', '-j', '2','-parse-as-library',str(f),str(t),str(r/'Sources/MacdirCore/MacIdentity.swift'),str(r/'Sources/MacdirCore/EgressLocation.swift'),'-o',str(exe)],check=True,timeout=40)
subprocess.run([str(exe)],check=True,timeout=15)
