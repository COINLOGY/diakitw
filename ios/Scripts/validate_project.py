from pathlib import Path
import json, plistlib, subprocess, xml.etree.ElementTree as ET
root = Path(__file__).resolve().parents[1]
p = plistlib.loads(subprocess.check_output(['plutil','-convert','xml1','-o','-',str(root/'diakitw.xcodeproj/project.pbxproj')]))
objects=p['objects']
assert p['rootObject'] in objects
for key,obj in objects.items():
    for field in ['buildConfigurationList','mainGroup','productRefGroup','productReference','fileRef']:
        if field in obj: assert obj[field] in objects, (key,field)
    for field in ['targets','children','files','buildPhases','buildConfigurations']:
        for ref in obj.get(field,[]): assert ref in objects, (key,ref)
    if obj['isa']=='PBXFileReference' and obj.get('sourceTree')=='<group>':
        assert (root/obj['path']).exists(),obj['path']
app=next(o for o in objects.values() if o['isa']=='PBXNativeTarget' and o['name']=='diakitw')
sources=next(objects[i] for i in app['buildPhases'] if objects[i]['isa']=='PBXSourcesBuildPhase')
paths=[objects[objects[b]['fileRef']]['path'] for b in sources['files']]
assert len(paths)==7
assert set(paths)=={'Sources/'+n+'.swift' for n in ['Dial','NetworkPolicy','BoundedTransfer','Monitor','DiakitwApp','UpdateChecker','UpdateSection']}
assert all(p.startswith('Sources/') for p in paths)
assert not any('Tests' in p for p in paths)
info=plistlib.loads((root/'Info.plist').read_bytes())
assert info['CFBundleShortVersionString']=='0.5.4' and info['CFBundleVersion']=='54'
assert 'NSAppTransportSecurity' not in info
scheme=ET.parse(root/'diakitw.xcodeproj/xcshareddata/xcschemes/diakitw.xcscheme')
for ref in scheme.iter('BuildableReference'): assert ref.attrib['BlueprintIdentifier'] in objects
for path in (root/'Assets.xcassets').rglob('Contents.json'):
    for image in json.loads(path.read_text()).get('images',[]):
        assert (path.parent/image['filename']).is_file()
print('PASS: Xcode graph, all file references, 7 app sources, scheme, version, ATS, assets (static only)')
