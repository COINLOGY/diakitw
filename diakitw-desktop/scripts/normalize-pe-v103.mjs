// Normalize the Windows PE fixed version; the portable 1.0.3 build is unsigned.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import * as PE from 'pe-library';
import * as RE from 'resedit';
const file='bundles-v103/diakitw-win32-x64/diakitw.exe';
const exe=PE.NtExecutable.from(fs.readFileSync(file));
const resources=PE.NtExecutableResource.from(exe);
const version=RE.Resource.VersionInfo.fromEntries(resources.entries)[0];
assert.ok(version,'Windows file version resource required');
const strings=version.getAllLanguagesForStringValues().map(lang=>version.getStringValues(lang));
assert.ok(strings.some(s=>s.FileVersion==='1.0.3.103'&&s.ProductName==='diakitw'),'Preserve verified version string before rewriting fixed info');
// lang=0 changes numeric VS_FIXEDFILEINFO only and preserves all string tables.
version.setFileVersion(1,0,3,103,0);
version.outputToResourceEntries(resources.entries);
resources.outputResource(exe);
fs.writeFileSync(file,Buffer.from(exe.generate()));
const fixed=RE.Resource.VersionInfo.fromEntries(PE.NtExecutableResource.from(PE.NtExecutable.from(fs.readFileSync(file))).entries)[0].fixedInfo;
assert.equal(fixed.fileVersionMS,(1<<16));
assert.equal(fixed.fileVersionLS,(3<<16)|103);
console.log('PASS Windows PE fixed version 1.0.3.103');
