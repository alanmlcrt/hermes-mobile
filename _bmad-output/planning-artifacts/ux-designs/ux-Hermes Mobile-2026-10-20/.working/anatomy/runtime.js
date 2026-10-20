const root=document.documentElement;
const systemDark=matchMedia('(prefers-color-scheme: dark)');
const reduced=matchMedia('(prefers-reduced-motion: reduce)');
const theme=document.querySelector('#theme');
const pauseButton=document.querySelector('#pause');
const phoneArt=document.querySelector('#phone-art');
const announcement=document.querySelector('#announcement');
const prompts={research:'Peux-tu faire cette recherche pour moi ?',read:'Peux-tu lire ce fichier et me le résumer ?',create:'Peux-tu me préparer un document ?',connect:'Utilise le service connecté à mon Hermes.'};
const captions={research:'Je rassemble les informations utiles.',read:'Je parcours le contenu du fichier.',create:'Je prépare le document.',connect:'Je communique avec le service.'};
let current=SCENES[0],state='running',paused=false,frame=0,last=0,clock=0,movers=[];
const visible=new Set();
function setTheme(){root.dataset.theme=theme.value==='system'?(systemDark.matches?'dark':'light'):theme.value;}
theme.addEventListener('change',setTheme);systemDark.addEventListener('change',setTheme);setTheme();
function collect(){
 movers=[];
 document.querySelectorAll('.art[data-scene]').forEach(host=>{
  const scene=SCENES.find(item=>item.id===host.dataset.scene);
  if(!scene)return;
  host.querySelectorAll('svg').forEach(svg=>{svg.setAttribute('aria-hidden','true');svg.removeAttribute('role');svg.removeAttribute('aria-label');svg.setAttribute('focusable','false');
   // Common crop around the measured complete base and bounded mechanism travel.
   svg.setAttribute('viewBox','130 112 340 204');
  });
  scene.motion.forEach(m=>{host.querySelectorAll(m.selector).forEach(el=>movers.push({host,el,...m}));});
 });
}
function draw(){for(const item of movers){
 if(!visible.has(item.host))continue;
 const fraction=reduced.matches?.5:(.5-.5*Math.cos(2*Math.PI*(clock/item.period+(item.phase||0))));
 item.el.setAttribute('transform','translate('+(item.dx*fraction).toFixed(3)+' '+(item.dy*fraction).toFixed(3)+')');
}}
function canRun(){return !paused&&!reduced.matches&&!document.hidden&&visible.size>0;}
function tick(now){frame=0;if(!canRun()){last=0;return;}clock+=last?Math.min((now-last)/1000,1/30):0;last=now;draw();frame=requestAnimationFrame(tick);}
function sync(){if(frame){cancelAnimationFrame(frame);frame=0;}last=0;draw();if(canRun())frame=requestAnimationFrame(tick);pauseButton.querySelector('span').textContent=reduced.matches?'Mouvements réduits':paused?'Reprendre':'Mettre en pause';pauseButton.setAttribute('aria-pressed',String(paused||reduced.matches));pauseButton.disabled=reduced.matches;}
const observer=new IntersectionObserver(entries=>{for(const entry of entries){if(entry.isIntersecting)visible.add(entry.target);else visible.delete(entry.target);}sync();},{rootMargin:'0px'});
document.querySelectorAll('.art').forEach(el=>observer.observe(el));
pauseButton.addEventListener('click',()=>{paused=!paused;sync();});reduced.addEventListener('change',sync);document.addEventListener('visibilitychange',sync);
function render(){
 const running=state==='running';
 document.querySelector('#task-title').textContent=state==='done'?'Travail terminé':state==='error'?'Un problème est survenu':state==='stop'?'Arrêt demandé':state==='unknown'?'Hermes travaille':current.title;
 document.querySelector('#running-label').textContent=state==='done'?'Terminé':state==='error'?'À vérifier':state==='stop'?'En attente':'En cours';
 document.querySelector('#reply').textContent=state==='done'?'C’est prêt.':state==='error'?'Je n’ai pas pu terminer cette demande.':'Je m’en occupe.';
 document.querySelector('#stage-caption').textContent=state==='done'?'Le résultat apparaîtra dans la conversation.':state==='error'?'Consulte les détails pour comprendre ce qui s’est passé.':state==='stop'?'En attente de la confirmation d’Hermes.':state==='unknown'?'Je traite ta demande.':captions[current.id];
 phoneArt.dataset.scene=running?current.id:'';
 phoneArt.innerHTML=running?current.svg:state==='unknown'?'<div class="generic-art"><span class="generic-orbit" aria-hidden="true"></span></div>':'<div class="result-symbol '+(state==='error'?'error':'')+'" aria-hidden="true">'+(state==='done'?'✓':state==='error'?'!':'Ⅱ')+'</div>';
 document.querySelector('#stop').hidden=state==='done'||state==='error';
 document.querySelector('#stop').disabled=state==='stop';
 document.querySelector('#prompt').textContent=prompts[current.id];
 document.querySelectorAll('[data-task]').forEach(el=>el.setAttribute('aria-pressed',String(el.dataset.task===current.id)));
 document.querySelectorAll('[data-state]').forEach(el=>el.setAttribute('aria-pressed',String(el.dataset.state===state)));
 collect();sync();announcement.textContent=document.querySelector('#task-title').textContent;
}
document.querySelectorAll('[data-task]').forEach(el=>el.addEventListener('click',()=>{current=SCENES.find(item=>item.id===el.dataset.task);state='running';render();}));
document.querySelectorAll('[data-state]').forEach(el=>el.addEventListener('click',()=>{state=el.dataset.state;render();}));
document.querySelector('#stop').addEventListener('click',()=>{state='stop';render();});
collect();sync();
