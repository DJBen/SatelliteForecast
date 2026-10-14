#!/usr/bin/env python3
"""Build the local native iPad star-density and annotation comparison gallery."""
import argparse
import json
from pathlib import Path
import re
import subprocess

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args();folder=args.output.resolve()
rows=json.loads((folder/'captures/manifest.json').read_text())
thumbs=folder/'thumbnails';thumbs.mkdir(exist_ok=True)
for r in rows:
    r['src']='captures/'+r['file'];r['thumbnail']='thumbnails/'+Path(r['file']).with_suffix('.jpg').name
    subprocess.run(['sips','--resampleWidth','700','-s','format','jpeg','-s','formatOptions','88',str(folder/r['src']),'--out',str(folder/r['thumbnail'])],check=True,stdout=subprocess.DEVNULL)
native=[]
for section in ['layouts','phone']:
    manifest=folder/section/'canvases/manifest.json'
    if not manifest.exists():continue
    for r in json.loads(manifest.read_text()):
        r['src']=section+'/canvases/'+r['file'];r['thumbnail']='thumbnails/native-'+Path(r['file']).with_suffix('.jpg').name
        subprocess.run(['sips','--resampleWidth','700','-s','format','jpeg','-s','formatOptions','88',str(folder/r['src']),'--out',str(folder/r['thumbnail'])],check=True,stdout=subprocess.DEVNULL)
        native.append(r)
nativecards=''
for r in native:
    title={'02-pass-chart':'Pass chart','03-pass-list':'Station pass browser','08-detailed-sky':'Expanded chart',
        '02-predictions-intro':'Onboarding replay', 'preview-cards':'List preview components'}[r['screen']]
    nativecards+='<article class="card"><a class="image" href="'+r['src']+'" target="_blank" rel="noopener"><img src="'+r['thumbnail']+'" alt="'+title+' '+r['canvas']+'" loading="lazy"></a><h3>'+title+'</h3><div class="meta">'+r['canvas']+' · '+str(r['widthPoints'])+' × '+str(r['heightPoints'])+' pt</div></article>'
counts=[r for r in rows if r['diameter']==700 and r['textSize']=='large']
adaptive = any(r['profile'].startswith('selected') and r['magnitude'] != 5.5 for r in rows)
if adaptive:
    counts = list({r['magnitude']:r for r in reversed(rows) if r['textSize']=='large'}.values())
    counts.sort(key=lambda r:r['magnitude'])
countrows=''.join('<tr><td>'+r['profile']+'</td><td>'+str(r['magnitude'])+'</td><td>'+format(r['catalogStars'],',')+'</td><td>'+format(r['aboveHorizonStars'],',')+'</td></tr>' for r in counts)
verification='<p>Density capture and five targeted behavior tests passed. Full behavior verification is pending.</p>'
report=folder/'behavior-tests.log'
if report.exists() and 'Passed: 173' in report.read_text() and 'Failed: 0' in report.read_text():
    verification='<p><strong>173 full behavior tests passed</strong>, with three optional review tests skipped and no failures. The 11-chart comparison and five focused detail tests also passed. iPad and iPhone feature captures passed their native hosting checks.</p>'
data=json.dumps(rows).replace('</','<\\/')
page=r'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SatelliteForecast · iPad sky detail exploration</title><style>
:root{color-scheme:dark;font:16px/1.5 -apple-system,BlinkMacSystemFont,sans-serif;background:#111417;color:#edf2f3}*{box-sizing:border-box}body{margin:0}header,main{max-width:1450px;margin:auto;padding:30px}header{border-bottom:1px solid #364146}h1{font-size:clamp(28px,4vw,46px);line-height:1.15;margin:12px 0}h2{font-size:24px;margin-top:30px}h3{font-size:18px}p{color:#b8c4c8;max-width:1000px}a{color:#a8ccd2}.eyebrow{color:#a8ccd2;font-size:12px;text-transform:uppercase;letter-spacing:.1em}button,select{font:inherit;background:#242c30;border:1px solid #52656c;color:inherit;border-radius:10px;padding:10px 14px;cursor:pointer}:focus-visible{outline:3px solid #a8ccd2;outline-offset:3px}.controls{display:flex;gap:20px;flex-wrap:wrap;align-items:center;margin:28px 0}.controls label{display:flex;gap:12px;align-items:center}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,340px),1fr));gap:24px}.card{border:1px solid #364146;background:#1b2226;border-radius:16px;padding:16px}.card h3{margin:12px 0 6px}.image{display:flex;align-items:center;justify-content:center;background:#111417;padding:0;height:460px;width:100%}.image img{max-width:100%;max-height:100%;object-fit:contain}.meta{color:#a8bbc2;font-size:13px}.card p{font-size:14px}table{border-collapse:collapse;width:min(800px,100%);margin:20px 0}td,th{border-bottom:1px solid #364146;padding:10px;text-align:left}.links{display:flex;gap:20px;flex-wrap:wrap}dialog{background:#111417;color:inherit;width:min(1400px,97vw);max-height:97vh;border:1px solid #5b7078;border-radius:14px;padding:20px}dialog::backdrop{background:#000d}.dialoghead{display:flex;justify-content:space-between;align-items:center;gap:20px}dialog img{display:block;max-width:100%;max-height:76vh;object-fit:contain;margin:14px auto}summary{cursor:pointer}details{margin:26px 0;border-top:1px solid #364146;padding-top:22px}@media(max-width:600px){header,main{padding:20px}.controls label{width:100%;justify-content:space-between}.image{height:400px}table{font-size:13px}}
</style></head><body><header><div class="eyebrow">SatelliteForecast · October 13, 2026 · dark native rendering</div><h1>iPad sky chart detail exploration</h1><p>The large chart can show fainter stars and localized constellation names while keeping the satellite path and brighter reference stars clear. This comparison uses the same reviewed ISS pass, observer and time for every density setting.</p><div class="links"><a href="../index.html">iPad layout gallery</a><a href="captures/manifest.json">Capture metadata</a><a href="capture-tests.log">Rendering and placement tests</a></div></header>
<main><h2>Recommended default</h2><p>Use magnitude 7.5 for charts at least 640 pt across, 6.5 for 480–639 pt, and the current magnitude 6 for smaller charts. Large charts gain constellation names and up to 12 bright-star names (16 in the 1000 pt expanded chart). Fainter points shrink gently to preserve the brightness hierarchy. Constellation names move around bright-star labels, planets and the orbit path; labels that do not fit are omitted.</p><p>The 7.5 profile adds depth with readable structure. The magnitude 8 trial is busier at 700 pt and is retained here for comparison. A chart's magnitude cutoff is a reference setting, not a prediction that every plotted star is visible from the observing location.</p><h2>Same sky, different magnitude limits</h2><table><thead><tr><th>Profile</th><th>Limit</th><th>Catalog stars</th><th>Above this horizon</th></tr></thead><tbody>COUNTROWS</tbody></table>
<div class="controls"><label>Chart size<select id="size"><option value="700">Large iPad chart · 700 pt</option><option value="1000">Expanded chart · 1000 pt</option><option value="adaptive">Adaptive mini and phone</option><option value="ax">Larger text</option><option value="all">All comparisons</option></select></label><span id="count" aria-live="polite"></span></div><div class="grid" id="gallery"></div>
<h2>In the complete screens</h2><p>These feature captures show the selected profile within the real pass layout, wide station browser and expanded chart. Pass/chart and station browser captures include root navigation; expanded chart captures host the feature content.</p><div class="grid">NATIVECARDS</div><h2>Implementation and verification</h2>VERIFICATION<p>Deeper star snapshots load on the catalog actor only when a chart requests them, with a maximum limit of 8 and one retained expanded snapshot per background model. The shared startup/planetarium catalog remains at 6.5. Rendering and hit testing use the same expanded catalog; constellation line endpoints remain available beyond the visible-star limit. Local drawing and expansion add no analytics events or fields.</p><p>These are Debug exploration changes following TestFlight 2.2.0 build 30. They are not part of that uploaded build. The comparison and five behavior tests check deeper catalog bounds, named-star preservation, cancellation, hit-testing catalog selection, deterministic label collision avoidance and horizon clipping. Native-view capture checks establish rendered output, not physical frame pacing or VoiceOver completion.</p><details><summary>Evidence boundaries</summary><p>Eleven dark hosted native-view captures on an iPad Pro simulator: four density settings at 700 and 1000 pt, adaptive 560 and 320 pt charts, and an Accessibility 1 chart. No invented stars are added; every point comes from the bundled catalog. The baseline recreates magnitude-6 settings with constellation names off, using the current renderer and retained constellation endpoints. Mini and phone examples are controlled canvases, not separate devices. Use the full-size original link for label and point detail. The timestamp, observer, TLE fixture and magnitude counts are recorded alongside each capture.</p><p>Latest prototype Debug installation succeeded on Sihao’s iPhone; launch was blocked by the lock screen. Device delivery is recorded in device-delivery.log. GPU frame pacing, live VoiceOver and resized-window interaction remain hardware checks.</p></details></main>
<dialog id="viewer"><div class="dialoghead"><h2 id="title"></h2><button id="close">Close</button></div><img id="full" alt=""><a id="original" target="_blank" rel="noopener">Open full-size original</a></dialog><script>
const rows=DATA,size=document.getElementById('size'),viewer=document.getElementById('viewer');
function show(r){document.getElementById('title').textContent=r.profile+' · '+r.diameter+' pt · magnitude '+r.magnitude;document.getElementById('full').src=r.src;document.getElementById('full').alt=r.profile+' native chart';document.getElementById('original').href=r.src;viewer.showModal()}
function render(){const items=rows.filter(r=>size.value==='all'||(size.value==='ax'?r.textSize!=='large':size.value==='adaptive'?r.diameter<700:r.diameter===Number(size.value)&&r.textSize==='large'));const g=document.getElementById('gallery');g.replaceChildren();for(const r of items){const a=document.createElement('article');a.className='card';const b=document.createElement('button');b.className='image';b.setAttribute('aria-label','Inspect '+r.profile);const im=document.createElement('img');im.src=r.thumbnail;im.alt=r.profile+' chart';im.loading='lazy';b.append(im);b.onclick=()=>show(r);const h=document.createElement('h3');h.textContent=r.profile+' · magnitude '+r.magnitude;const m=document.createElement('div');m.className='meta';m.textContent=r.diameter+' pt · '+r.aboveHorizonStars.toLocaleString()+' stars above horizon · '+r.textSize;const p=document.createElement('p');p.textContent=r.constellationNames?'Constellation names and more bright-star names; faint points use the finer detail profile.':'Current magnitude-6 density and a small bright-star-name budget.';a.append(b,h,m,p);g.append(a)}document.getElementById('count').textContent=items.length+' captures';location.hash=size.value}
size.onchange=render;document.getElementById('close').onclick=()=>viewer.close();const v=location.hash.slice(1);if([...size.options].some(o=>o.value===v))size.value=v;render();
</script></body></html>'''
selected = all(r['profile'].startswith('selected') for r in rows)
if selected:
    page = page.replace('iPad sky chart detail exploration', 'Selected sky chart · magnitude 5.5')
    page = page.replace('The large chart can show fainter stars and localized constellation names while keeping the satellite path and brighter reference stars clear.',
        'The selected chart uses a quieter star field while retaining localized constellation names and clear bright-star references.')
    page = re.sub(r'<main><h2>Recommended default</h2>.*?<h2>Same sky, different magnitude limits</h2>',
        '<main><h2>Selected default</h2><p>Magnitude 5.5 is the chosen star limit for regular and expanded pass charts at every size. Constellation names appear on charts at least 480 pt across; bright-star names retain priority. Label placement avoids the satellite path, planets and other labels.</p><p><a href="../index.html">Previous density exploration</a></p><h2>Selected star density</h2>', page, flags=re.S)
    page = page.replace('This comparison uses the same reviewed ISS pass, observer and time for every density setting.',
        'These captures use the selected magnitude-5.5 default and the same reviewed ISS pass, observer and time.')
    page = re.sub(r'<p>Deeper star snapshots load.*?</p>',
        '<p>The magnitude-5.5 default filters the existing catalog and does not request a deeper snapshot. Constellation line endpoints remain available beyond the visible-star limit. Rendering and star selection use the same requested magnitude cutoff. Local drawing adds no analytics events or fields.</p>', page, flags=re.S)
    page = re.sub(r'<p>Eleven dark hosted native-view captures.*?</p>',
        '<p>Five fresh dark native-view captures on an iPad Pro simulator: selected charts at 320, 560, 700 and 1000 pt, plus an Accessibility 1 chart. Mini and phone sizes are controlled canvases. Full-screen examples below use the same selected default. Star counts and fixture metadata are recorded with each capture.</p>', page, flags=re.S)
    page = page.replace('faint points use the finer detail profile.', 'stars use the selected magnitude-5.5 limit.')
    page = page.replace('Current magnitude-6 density and a small bright-star-name budget.',
        'Magnitude-5.5 density and a compact bright-star-name budget.')
    page = page.replace('href="../index.html">iPad layout gallery', 'href="../../index.html">iPad layout gallery')
    verification = f'<p>The {len(rows)} selected-profile captures and five catalog/label behavior tests passed. The prior exploration passed 173 full behavior tests; subsequent adjustments received focused checks.</p>'
    delivery = folder/'device-delivery.log'
    if delivery.exists() and 'App launched successfully' in delivery.read_text():
        page = page.replace('Latest prototype Debug installation succeeded on Sihao’s iPhone; launch was blocked by the lock screen.',
            'Selected magnitude-5.5 Debug build installed and launched successfully on Sihao’s iPhone.')
    if adaptive:
        verification = f'<p>All eight focused checks passed: the {len(rows)}-capture matrix, five catalog/label behavior tests, animated onboarding stability and density changes on a fixed-size canvas. Full-screen captures provide additional visual evidence.</p>'
        page = page.replace('Selected sky chart · magnitude 5.5', 'Sky chart density by size')
        page = page.replace('The selected chart uses a quieter star field while retaining localized constellation names and clear bright-star references.',
            'Star density follows chart size, keeping small previews clear and larger charts detailed.')
        page = page.replace('These captures use the selected magnitude-5.5 default', 'These captures use the selected adaptive defaults')
        page = page.replace('Magnitude 5.5 is the chosen star limit for regular and expanded pass charts at every size.',
            'Charts under 240 pt use magnitude 3; charts from 240 to 479 pt use magnitude 4.5; charts at least 480 pt use magnitude 5.5. Expanded charts use the visible viewport to choose density, even though their scrollable canvas is 1000 pt. List previews keep their compact styling.')
        page = page.replace('The magnitude-5.5 default filters', 'The adaptive defaults filter')
        page = page.replace('stars use the selected magnitude-5.5 limit.', 'stars use the selected size-dependent limit.')
        page = page.replace('Magnitude-5.5 density and a compact bright-star-name budget.', 'Size-dependent density and a compact bright-star-name budget.')
        page = page.replace('Selected magnitude-5.5 Debug build', 'Adaptive-density Debug build')
        page = page.replace('Adaptive mini and phone', 'Small charts and size boundaries')
        page = page.replace('<a href="../index.html">Previous density exploration</a>',
            '<a href="../sky-detail/index.html">Previous density exploration</a>')
        page = page.replace('href="../../index.html">iPad layout gallery', 'href="../index.html">iPad layout gallery')
        page = re.sub(r'<p>Five fresh dark native-view captures.*?</p>',
            f'<p>{len(rows)} dark native-view captures cover the two size boundaries, regular phone charts, large iPad charts and larger text. These controlled circles verify star limits using the full-chart style; list previews preserve their simpler style. Full-screen examples below show the adaptive defaults in context. Star counts and fixture metadata are recorded with each capture.</p>', page, flags=re.S)
elif (folder/'selected-5.5/index.html').exists():
    page = page.replace('<main>', '<main><p><strong>Selected default: magnitude 5.5.</strong> <a href="selected-5.5/index.html">See fresh selected-profile screenshots.</a> The comparisons and initial recommendation below record the earlier exploration.</p>', 1)
(folder/'index.html').write_text(page.replace('DATA',data).replace('COUNTROWS',countrows).replace('NATIVECARDS',nativecards).replace('VERIFICATION',verification))
print(folder/'index.html')
