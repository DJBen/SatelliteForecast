#!/usr/bin/env python3
"""Build a local, filterable gallery from iPad UX evidence; preserve full-size originals."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
folder = args.output.resolve()
manifest = json.loads((folder / "canvases/manifest.json").read_text())
titles = {"01-forecast": "Next observation", "02-pass-chart": "Pass chart", "03-pass-list": "Station pass list",
          "04-satellites": "Satellites", "05-planetarium": "Planetarium preview", "01-welcome": "Welcome",
          "02-predictions-intro": "Predictions introduction", "05-satellite-list": "Satellite search content",
          "09-sky-now": "Sky now content", "10-settings": "Settings content", "11-location": "Location selection content",
          "13-pass-alarm": "Alarm editor", "alarms-empty": "Empty alarms", "alarms-saved": "Saved alarms"}
notes = {"01-forecast": "P1 · Bound the card width and give the sky preview useful space.",
         "02-pass-chart": "P1 · The large circle pushes controls and event times below the first viewport.",
         "03-pass-list": "P1 · Keep the pass list beside its selected chart at wide widths.",
         "04-satellites": "P1 · Use a card grid; wide fixed-height media crops the imagery.",
         "05-planetarium": "Keep · The immersive sky makes good use of the display. Input and resizing still need live validation.",
         "01-welcome": "P2 · Cap reading and button widths; compose the media for both orientations.",
         "02-predictions-intro": "P2 · Balance the demonstration and copy at tablet sizes.",
         "05-satellite-list": "P1 · A very wide single-row list needs a bounded list/detail layout.",
         "09-sky-now": "Keep · Large sky canvas with one fixture satellite; live catalog loading and selection remain unverified.",
         "10-settings": "P1 · Constrain forms to a comfortable reading width.",
         "11-location": "P1 · Constrain location content; verify search keyboard and presentation live.",
         "13-pass-alarm": "P1 · Use a focused sheet rather than a full-width editor.",
         "alarms-empty": "P2 · Keep the empty-state action close to its explanation.",
         "alarms-saved": "P1 · Bound rows so alert time and satellite stay visually connected."}
canvas_order = ["pro-portrait", "pro-landscape", "mini-portrait", "narrow-window"]
screen_order = list(titles)
manifest.sort(key=lambda c: (canvas_order.index(c["canvas"]), screen_order.index(c["screen"]), c["textSize"] != "large"))
for item in manifest:
    item["src"] = "canvases/" + item["file"]
    item["title"] = titles[item["screen"]] + (" · larger text" if item["textSize"] != "large" else "")
    item["note"] = notes[item["screen"]]
baseline = [
    {"src": "screenshots/01-current-compatibility-welcome.png", "title": "Current build · welcome",
     "note": "P0 · The shipping configuration targets iPhone only. Actual iPad simulator screenshot."},
    {"src": "screenshots/03-current-compatibility-home.png", "title": "Current build · home",
     "note": "The app occupies a narrow compatibility window. This live capture uses simulated Redwood City."}
]
thumbs = folder / "thumbnails"
thumbs.mkdir(exist_ok=True)
for item in baseline + manifest:
    src = folder / item["src"]
    if not src.is_file():
        raise SystemExit(f"Missing screenshot: {src}")
    thumb = thumbs / (src.stem + ".jpg")
    subprocess.run(["sips", "--resampleWidth", "640", "-s", "format", "jpeg", "-s", "formatOptions", "85",
                    str(src), "--out", str(thumb)], check=True, stdout=subprocess.DEVNULL)
    item["thumbnail"] = "thumbnails/" + thumb.name
data = json.dumps({"baseline": baseline, "captures": manifest}, ensure_ascii=False).replace("</", "<\\/")
page = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SatelliteForecast · iPad UX review</title>
<style>
:root{color-scheme:dark;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#101216;color:#eef1f5}
*{box-sizing:border-box}body{margin:0}main,header{max-width:1440px;margin:auto;padding:32px}header{padding-top:48px;border-bottom:1px solid #343942}
h1{font-size:clamp(28px,4vw,48px);letter-spacing:-.04em;margin:10px 0 18px;line-height:1.1}h2{font-size:24px;margin:0 0 14px}h3{font-size:16px;margin:12px 0 6px}p{margin:8px 0;color:#bec5cf}header p{max-width:850px}.eyebrow{font-size:12px;letter-spacing:.1em;color:#b8c9e3;text-transform:uppercase}
a{color:#b8c9e3}button,select{font:inherit;color:inherit;background:#242932;border:1px solid #47505e;border-radius:9px;padding:10px 14px;cursor:pointer}button:hover,select:hover{background:#303846}button:focus-visible,a:focus-visible,select:focus-visible{outline:3px solid #b8c9e3;outline-offset:3px}
.links,.controls{display:flex;gap:12px;flex-wrap:wrap;align-items:center}.links{margin-top:22px}.controls{margin:24px 0}.controls label{display:flex;align-items:center;gap:10px}.controls span{color:#bec5cf}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,330px),1fr));gap:28px}.baseline{max-width:780px;margin:22px 0 42px}.capture{min-width:0}.capture .image{display:flex;align-items:center;justify-content:center;width:100%;height:480px;padding:0;background:#181c22;border:1px solid #343942;border-radius:12px;overflow:hidden}.capture img{display:block;max-width:100%;max-height:100%;object-fit:contain}.capture p{font-size:14px}.meta{color:#9ca9bb;font-size:12px}.divider{border-top:1px solid #343942;margin-top:36px;padding-top:28px}
dialog{width:min(1400px,96vw);max-height:96vh;padding:20px;border:1px solid #626e81;border-radius:12px;background:#101216;color:#eef1f5}dialog::backdrop{background:#000d}.dialog-header{display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap}.dialog-header h2{margin:0;font-size:20px}dialog img{display:block;max-width:100%;max-height:70vh;margin:18px auto;object-fit:contain}dialog .buttons{display:flex;gap:8px}details{margin:24px 0}summary{cursor:pointer}footer{border-top:1px solid #343942;padding-top:24px;color:#9ca9bb;font-size:14px}@media(max-width:600px){main,header{padding:22px}.capture .image{height:390px}.controls label{width:100%;justify-content:space-between}.controls select{max-width:65%}dialog{padding:14px}}
</style></head><body>
<header><div class="eyebrow">SatelliteForecast · October 12, 2026 · dark mode</div>
<h1>A strong sky experience.<br>Layouts still built around a phone.</h1>
<p>The first gap is native iPad support. The diagnostic canvases then reveal oversized charts, stretched cards and forms, and missed opportunities to keep lists beside their detail views.</p>
<div class="links"><a href="review-and-plan.md">Read the prioritized review and implementation plan</a><a href="evidence.json">Capture context</a></div></header>
<main><section><h2>What the current build shows</h2><p>Two actual iPad Pro simulator screenshots of the unchanged iPhone-only configuration.</p><div id="baseline" class="grid baseline"></div></section>
<section class="divider"><h2>Native iPad layout diagnostics</h2>
<p>CAPTURE_COUNT hosted native-view captures on an iPad simulator, with an isolated universal build override. The canvas sizes below are controlled layouts, not separate physical device or window-resizing tests.</p>
<div class="controls"><label>Canvas<select id="canvas"><option value="pro-portrait">13-inch Pro · portrait</option><option value="pro-landscape">13-inch Pro · landscape</option><option value="mini-portrait">Mini-size · portrait</option><option value="narrow-window">Narrow window · 500 pt</option><option value="all">All canvases</option></select></label><label>Screen<select id="screen"><option value="all">All screens</option></select></label><span id="count" aria-live="polite"></span></div>
<div id="gallery" class="grid"></div></section>
<details><summary>Evidence boundaries</summary><p>The main Home, pass chart, station list and Satellites captures include the real root tab bar. Secondary settings, location, alarm and onboarding views are captured as feature content. Fixture weather is illustrative; Sky now uses one fixture satellite. System glass may sample the simulator wallpaper and is not a stable color baseline. Simulated location, orbital epochs, locale and time zone are recorded in the capture context. Physical iPad input, permissions, rotation continuity, resizing and rendering performance require follow-up validation.</p></details>
<footer>Original PNGs are preserved at 2× scale. Select any image to inspect it; the dialog also links to its full-size original. Application source and shipping device-family settings were not changed.</footer>
</main>
<dialog id="viewer" aria-labelledby="viewer-title"><div class="dialog-header"><h2 id="viewer-title"></h2><div class="buttons"><button id="previous" aria-label="Previous capture">←</button><button id="next" aria-label="Next capture">→</button><button id="close">Close</button></div></div><img id="viewer-image" alt=""><p id="viewer-note"></p><a id="original" target="_blank" rel="noopener">Open full-size original</a></dialog>
<script>
const data=DATA,canvas=document.getElementById('canvas'),screen=document.getElementById('screen'),viewer=document.getElementById('viewer');
let current=[],index=0;
for(const name of [...new Set(data.captures.map(c=>c.screen))]){const option=document.createElement('option');option.value=name;option.textContent=data.captures.find(c=>c.screen===name).title;screen.append(option)}
function show(items,i){current=items;index=(i+items.length)%items.length;const c=items[index];document.getElementById('viewer-title').textContent=c.title;document.getElementById('viewer-image').src=c.src;document.getElementById('viewer-image').alt=c.title;document.getElementById('viewer-note').textContent=c.note;document.getElementById('original').href=c.src;if(!viewer.open)viewer.showModal()}
function card(c,items,i){const article=document.createElement('article');article.className='capture';const button=document.createElement('button');button.className='image';button.setAttribute('aria-label','Inspect '+c.title);const image=document.createElement('img');image.src=c.thumbnail;image.alt=c.title;image.loading='lazy';button.append(image);button.onclick=()=>show(items,i);article.append(button);const title=document.createElement('h3');title.textContent=c.title;article.append(title);if(c.canvas){const meta=document.createElement('div');meta.className='meta';meta.textContent=c.canvas+' · '+c.widthPoints+' × '+c.heightPoints+' pt · '+c.textSize;article.append(meta)}const note=document.createElement('p');note.textContent=c.note;article.append(note);return article}
data.baseline.forEach((c,i)=>document.getElementById('baseline').append(card(c,data.baseline,i)));
function render(){const items=data.captures.filter(c=>(canvas.value==='all'||c.canvas===canvas.value)&&(screen.value==='all'||c.screen===screen.value));const gallery=document.getElementById('gallery');gallery.replaceChildren();items.forEach((c,i)=>gallery.append(card(c,items,i)));document.getElementById('count').textContent=items.length+' captures';location.hash=canvas.value+'/'+screen.value}
canvas.onchange=render;screen.onchange=render;document.getElementById('close').onclick=()=>viewer.close();document.getElementById('previous').onclick=()=>show(current,index-1);document.getElementById('next').onclick=()=>show(current,index+1);viewer.addEventListener('keydown',e=>{if(e.key==='ArrowLeft'){e.preventDefault();show(current,index-1)}if(e.key==='ArrowRight'){e.preventDefault();show(current,index+1)}});
const parts=location.hash.slice(1).split('/');if([...canvas.options].some(o=>o.value===parts[0]))canvas.value=parts[0];if([...screen.options].some(o=>o.value===parts[1]))screen.value=parts[1];render();
</script></body></html>'''
(folder / "index.html").write_text(page.replace("CAPTURE_COUNT", str(len(manifest))).replace("DATA", data))
print(folder / "index.html")
