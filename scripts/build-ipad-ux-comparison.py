#!/usr/bin/env python3
"""Build the dark before/after gallery from native layout capture manifests."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--baseline', type=Path, required=True)
args = parser.parse_args()
folder, baseline = args.output.resolve(), args.baseline.resolve()
manifest = json.loads((folder / 'final/canvases/manifest.json').read_text())
old = {item['file']: item for item in json.loads((baseline / 'canvases/manifest.json').read_text())}
titles = {'01-forecast':'Home', '02-pass-chart':'Pass chart', '03-pass-list':'Station passes',
          '04-satellites':'Satellites', '05-satellite-list':'Satellite browsing', '09-sky-now':'Sky now',
          '10-settings':'Settings', '11-location':'Location', '13-pass-alarm':'Alarm editor',
          'alarms-saved':'Saved alarms', '01-welcome':'Welcome', '02-predictions-intro':'Predictions introduction'}
notes = {'01-forecast':'Bounded Home composition, a larger sky panel, finer orbit stroke, six upcoming passes on wide windows, and consistent action styling.',
         '02-pass-chart':'Retina chart layers, denser catalog stars, higher-resolution Milky Way, and chart/actions/timeline beside one another in wide windows.',
         '03-pass-list':'Wide list/detail selection keeps neighboring passes visible. Narrow windows keep stack navigation.',
         '04-satellites':'Two station cards and an adaptive category grid; images keep a 16:9 aspect ratio and titles wrap.',
         '05-satellite-list':'Wide catalog/detail browsing with search focus via Command-F. This fixture contains one station.',
         '09-sky-now':'Selected-satellite and passing-status cards have bounded widths. The immersive sky stays dominant.',
         '10-settings':'Centered settings content with a comfortable reading width.',
         '11-location':'Bounded results and Command-F search focus. Live keyboard/confirmation behavior still requires hardware validation.',
         '13-pass-alarm':'Bounded editor content and consistent Save styling. Production alarm presentation uses a form sheet; this capture hosts the editor content directly.',
         'alarms-saved':'Bounded alarm rows, consistent actions, and large-text reflow.',
         '01-welcome':'Introduction and action form a focused panel beside the moving sky at wide widths; compact windows retain the video overlay. The fixture freezes a video frame.',
         '02-predictions-intro':'Recorded pass demonstration beside a focused introduction/action panel on wide windows, with a stacked compact fallback.'}
canvases = ['pro-portrait','pro-landscape','mini-portrait','narrow-window','phone-portrait','phone-small']
manifest.sort(key=lambda x:(canvases.index(x['canvas']),list(titles).index(x['screen']),x['textSize']!='large'))
thumbs = folder/'thumbnails'; thumbs.mkdir(exist_ok=True)
for item in manifest:
    item['title'] = titles[item['screen']] + (' · Accessibility 3' if item['textSize']!='large' else '')
    item['note'] = notes[item['screen']]
    item['after'] = 'final/canvases/'+item['file']
    if item['file'] in old:
        item['before'] = '../'+baseline.name+'/canvases/'+item['file']
    for phase in ['before','after']:
        if phase not in item: continue
        source = folder/item[phase]
        target = thumbs/(phase+'-'+source.stem+'.jpg')
        subprocess.run(['sips','--resampleWidth','640','-s','format','jpeg','-s','formatOptions','85',str(source),'--out',str(target)],check=True,stdout=subprocess.DEVNULL)
        item[phase+'Thumb']='thumbnails/'+target.name
(folder/'comparison.json').write_text(json.dumps(manifest,indent=2)+'\n')
data=json.dumps(manifest).replace('</','<\\/')
page=r'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SatelliteForecast · Updated iPad UX</title>
<style>
:root{color-scheme:dark;font:16px/1.5 -apple-system,BlinkMacSystemFont,sans-serif;background:#111417;color:#edf2f3}*{box-sizing:border-box}body{margin:0}header,main{max-width:1500px;margin:auto;padding:32px}header{border-bottom:1px solid #333b40}h1{font-size:clamp(30px,4vw,52px);line-height:1.12;letter-spacing:-.035em;margin:12px 0 20px}h2{font-size:22px}p{color:#b8c1c6;max-width:920px}.eyebrow{color:#a8ccd2;font-size:12px;text-transform:uppercase;letter-spacing:.12em}a{color:#a8ccd2}button,select{font:inherit;background:#232a2e;color:inherit;border:1px solid #4c5a60;border-radius:10px;padding:10px 14px;cursor:pointer}:focus-visible{outline:3px solid #a8ccd2;outline-offset:3px}.controls{display:flex;gap:18px;flex-wrap:wrap;margin:24px 0}.controls label{display:flex;gap:10px;align-items:center}.controls span{color:#b8c1c6;align-self:center}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,550px),1fr));gap:30px}.card{background:#191f23;border:1px solid #333b40;border-radius:16px;padding:18px;min-width:0}.card h2{margin:0 0 6px}.meta{font-size:13px;color:#9caeb5}.pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin-top:18px}.pair.single{grid-template-columns:1fr}.image{width:100%;height:370px;padding:0;display:flex;align-items:center;justify-content:center;background:#0e1113;overflow:hidden}.image img{max-width:100%;max-height:100%;object-fit:contain}.phase{font-size:12px;color:#a8ccd2;display:block;margin-bottom:7px}.card p{font-size:14px;margin-bottom:0}details{border-top:1px solid #333b40;margin-top:30px;padding-top:24px}summary{cursor:pointer}dialog{width:min(1550px,97vw);max-height:97vh;padding:22px;border:1px solid #586970;border-radius:16px;background:#111417;color:inherit}dialog::backdrop{background:#000d}.dialoghead{display:flex;justify-content:space-between;gap:20px;align-items:center}.dialoghead h2{margin:0}.viewer img{display:block;max-width:100%;max-height:70vh;margin:auto}.viewer a{display:block;font-size:13px;margin-top:8px}.viewer .pair{margin-top:18px}.links{display:flex;flex-wrap:wrap;gap:20px}li{margin-bottom:8px}@media(max-width:700px){header,main{padding:20px}.image{height:290px}.viewer .pair{grid-template-columns:1fr}.viewer img{max-height:65vh}.controls label{width:100%;justify-content:space-between}select{max-width:70%}}
</style></head><body><header><div class="eyebrow">SatelliteForecast · October 13, 2026 · dark mode</div><h1>More sky detail.<br>Clearer iPad layouts.</h1><p>Home now gives the sky an intentional panel beside upcoming passes. Wide charts keep their timeline and actions visible, satellite browsing uses the available space, and forms and buttons follow shared sizing and color rules.</p><div class="links"><a href="../2026-10-12/index.html">Original review</a><a href="comparison.json">Capture manifest</a><a href="#verification">Verification and remaining checks</a></div></header>
<main><div class="controls"><label>Canvas<select id="canvas"><option value="pro-landscape">13-inch Pro · landscape</option><option value="pro-portrait">13-inch Pro · portrait</option><option value="mini-portrait">Mini-size · portrait</option><option value="narrow-window">500 pt window</option><option value="phone-portrait">iPhone Pro Max-size</option><option value="phone-small">Small iPhone-size</option><option value="all">All canvases</option></select></label><label>Screen<select id="screen"><option value="all">All screens</option></select></label><span id="count" aria-live="polite"></span></div><div class="grid" id="gallery"></div>
<section id="verification"><h2>Verification and remaining checks</h2><div id="verification-content">VERIFICATION</div></section>
<details><summary>How to read this evidence</summary><p>These are deterministic native-view canvases, hosted on iPad Pro 13-inch (M5) and iPhone 17 Pro Max simulators running iOS 27. Mini, small-phone and narrow-window sizes are controlled canvases, not separate hardware runs. Home, pass chart, station passes and Satellites include root navigation; other captures host feature content. Weather is illustrative, Sky now contains one fixture satellite, and onboarding freezes the video/replay. The California moment, observer, time zone and TLEs are preserved from the original review. The satellite-browser fixture now seeds a station's passes to show its selected detail; the old fixture did not.</p><p>Native app and widget device families now include iPad. System tab-bar glass may sample the simulator wallpaper; the cyan controls and dark cards use app-defined colors. Hosted captures establish layout and rendering evidence. They do not establish physical touch, VoiceOver, keyboard focus, permission workflows or rotation continuity.</p></details></main>
<dialog id="viewer" class="viewer" aria-labelledby="viewer-title"><div class="dialoghead"><h2 id="viewer-title"></h2><button id="close">Close</button></div><div id="viewer-pair" class="pair"></div><p id="viewer-note"></p></dialog>
<script>
const data=DATA,canvas=document.getElementById('canvas'),screen=document.getElementById('screen'),viewer=document.getElementById('viewer');
for(const name of [...new Set(data.map(c=>c.screen))]){const o=document.createElement('option');o.value=name;o.textContent=data.find(c=>c.screen===name).title;screen.append(o)}
function pair(c,full=false){const box=document.createElement('div');box.className='pair'+(!c.before?' single':'');for(const phase of ['before','after']){if(!c[phase])continue;const group=document.createElement('div'),label=document.createElement('span');label.className='phase';label.textContent=phase==='before'?'BEFORE · OCT 12':'AFTER · OCT 13';group.append(label);const im=document.createElement('img');im.src=full?c[phase]:c[phase+'Thumb'];im.alt=c.title+' '+phase;if(full){group.append(im);const a=document.createElement('a');a.href=c[phase];a.target='_blank';a.rel='noopener';a.textContent='Open full-size original';group.append(a)}else{im.loading='lazy';const b=document.createElement('button');b.className='image';b.setAttribute('aria-label','Inspect '+c.title+' '+phase);b.append(im);b.onclick=()=>show(c);group.append(b)}box.append(group)}return box}
function show(c){document.getElementById('viewer-title').textContent=c.title+' · '+c.canvas;document.getElementById('viewer-pair').replaceWith(Object.assign(pair(c,true),{id:'viewer-pair'}));document.getElementById('viewer-note').textContent=c.note;viewer.showModal()}
function render(){const items=data.filter(c=>(canvas.value==='all'||c.canvas===canvas.value)&&(screen.value==='all'||c.screen===screen.value));const g=document.getElementById('gallery');g.replaceChildren();for(const c of items){const a=document.createElement('article');a.className='card';const h=document.createElement('h2');h.textContent=c.title;a.append(h);const m=document.createElement('div');m.className='meta';m.textContent=c.canvas+' · '+c.widthPoints+' × '+c.heightPoints+' pt · '+c.textSize;a.append(m,pair(c));const p=document.createElement('p');p.textContent=c.note;a.append(p);g.append(a)}document.getElementById('count').textContent=items.length+' updated captures';location.hash=canvas.value+'/'+screen.value}
canvas.onchange=render;screen.onchange=render;document.getElementById('close').onclick=()=>viewer.close();const parts=location.hash.slice(1).split('/');if([...canvas.options].some(o=>o.value===parts[0]))canvas.value=parts[0];if([...screen.options].some(o=>o.value===parts[1]))screen.value=parts[1];render();
</script></body></html>'''
verification=(folder/'verification.html').read_text() if (folder/'verification.html').exists() else '<p>Verification is in progress.</p>'
(folder/'index.html').write_text(page.replace('DATA',data).replace('VERIFICATION',verification))
print(folder/'index.html')
