from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'Sources/DiagnosticWorker/main.swift').read_text()
ram=s[s.index('case "ram":'):s.index('case "gpu":')]
assert 'let requestedBytes = DiagnosticLimits.allowedBytes' in ram, 'allocation must remain zero until malloc succeeds'
assert ram.index('allocated = requestedBytes') > ram.index('else { finish("unavailable-memory"'), 'only actual allocation reported'
assert 'guard requestedBytes >= 65536, let memory = malloc(requestedBytes)' in ram
print('Worker actual-allocation source invariant PASS (malloc failure not forced live)')
