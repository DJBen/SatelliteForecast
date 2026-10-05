const screen=document.querySelector('#screen'),size=document.querySelector('#text-size'),data=window.reviewData;
for(const row of data){const option=document.createElement('option');option.value=row.id;option.textContent=row.title;screen.append(option);}
const revision=document.querySelector('#revision');
function show(){
 const row=data.find(x=>x.id===screen.value), before=revision.value==='before';
 const largeKey=before?row.beforeLarge:row.large;
 size.options[1].disabled=!largeKey;
 if(!largeKey) size.value='normal';
 const large=size.value==='large', variant=large?largeKey:row.normal;
 const base='assets/'+(before?'outer-default/':'implementation-pass-1/')+variant;
 const name=row.title+(large?' · larger text':'');
 document.querySelector('#shot').src=base+'.jpg';
 document.querySelector('#shot').alt=name+' · '+(before?'before':'after implementation pass 1')+' on the native iPhone Duo outer display in dark mode';
 document.querySelector('#full').href=base+'.jpg';document.querySelector('#original').href=base+'.png';
 document.querySelector('#screen-title').textContent=name;
 document.querySelector('#screen-note').textContent=before?(large?row.beforeLargeNote:row.beforeNote):(large?row.largeNote:row.note);
 document.querySelector('#caption').textContent=(before?'Before · baseline':'After · implementation pass 1')+' · outer display · 466 × 678 points · '+(large?'accessibility2 text':'standard text')+' · dark mode. Tap the image to view at full size.';
 document.querySelector('#previous').disabled=screen.selectedIndex===0;document.querySelector('#next').disabled=screen.selectedIndex===data.length-1;
}
revision.addEventListener('change',show);
screen.addEventListener('change',show);size.addEventListener('change',show);document.querySelector('#previous').addEventListener('click',()=>{screen.selectedIndex--;show();});document.querySelector('#next').addEventListener('click',()=>{screen.selectedIndex++;show();});document.querySelectorAll('[data-screen]').forEach(button=>button.addEventListener('click',()=>{revision.value='after';screen.value=button.dataset.screen;size.value=button.dataset.size;show();document.querySelector('#evidence').scrollIntoView({behavior:matchMedia('(prefers-reduced-motion:reduce)').matches?'instant':'smooth'});screen.focus({preventScroll:true});}));
const pose=document.querySelector('#pose'),notes={outer:'On the outer display, show one clear flow. Keep the selected pass and reminder action together.',flat:'On the inner flat display, browse passes beside the selected pass. Adapt to available pane width rather than stretching a phone card.',book:'In a book pose, keep the list and selected pass on separate sides of the active division. Keep controls away from the fold.',tabletop:'In a tabletop pose, put the sky view above the fold and the timeline and reminder controls below it. This concept represents grouping only; hardware ergonomics still need testing.'};pose.addEventListener('change',()=>{document.querySelector('#concept').className='concept-layout '+pose.value;document.querySelector('#pose-note').textContent=notes[pose.value];});show();
