import json,time,subprocess,pathlib,sys,shutil
root=pathlib.Path('/Users/sihaolu/Developments/SatelliteForecast/Documentation/DesignReview/iPhoneDuo-2026-10-03')
pose=sys.argv[1]; display=sys.argv[2]
keys=sys.argv[3:] or ['tabs-01-forecast','tabs-02-pass-chart','tabs-03-pass-list','tabs-04-satellites','tabs-05-planetarium','07-pass','07-pass-compass-off','10-settings','11-location','12-alarms','13-pass-alarm','01-welcome','02-predictions-intro']
folder=root/'screenshots'/pose; folder.mkdir(parents=True,exist_ok=True)
for key in keys:
    large=key.endswith('+large'); screen=key.removesuffix('+large'); token=f'{pose}-{key}-{time.time_ns()}'
    command=pathlib.Path('/tmp/duo-review-command.json')
    temp=command.with_suffix('.new'); temp.write_text(json.dumps({'token':token,'screen':screen,'largeText':large})); temp.replace(command)
    for _ in range(120):
        try:
            meta=json.loads(pathlib.Path(str(command)+'.ready').read_text())
            if meta.get('token')==token:break
        except (FileNotFoundError,json.JSONDecodeError):pass
        time.sleep(.25)
    else:raise RuntimeError('Capture harness did not acknowledge '+screen)
    meta.update({'pose':pose,'simulator':'iPhone Duo','simulatorID':'7C40B063-AE4F-4981-9915-EDCD4DF343A5','displayPort':display,'xcode':'27.1 beta (27A9269)','runtime':'iOS 27.1 beta (24A94401)','captureMethod':'Native simulator display; app view fixture in real UIWindowScene','file':key+'.png'})
    (folder/(key+'.json')).write_text(json.dumps(meta,indent=2))
    subprocess.run(['/Applications/Xcode-27.1-beta.app/Contents/Developer/usr/bin/simctl','io',meta['simulatorID'],'screenshot','--display='+display,str(folder/(key+'.png'))],check=True,stdout=subprocess.DEVNULL)
    print(pose,key,meta['windowBounds'],flush=True)
