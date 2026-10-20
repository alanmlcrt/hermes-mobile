const root=document.documentElement,theme=document.querySelector('#theme'),pauseButton=document.querySelector('#pause'),phoneArt=document.querySelector('#phone-art'),announcement=document.querySelector('#announcement');
const systemDark=matchMedia('(prefers-color-scheme: dark)'),reduced=matchMedia('(prefers-reduced-motion: reduce)');
const prompts={code:'Peux-tu écrire ce code pour moi ?',research:'Peux-tu faire cette recherche pour moi ?',read:'Peux-tu lire ce fichier et me le résumer ?',create:'Peux-tu me créer un fichier ?',connect:'Utilise cet outil sur mon Hermes.'};
const captions={code:'Je prépare le code.',research:'Je rassemble les informations utiles.',read:'Je parcours le contenu du fichier.',create:'Je crée le fichier.',connect:'Je fais appel à l’outil.'};
let current=SCENES[0],state='running',paused=false,tourTimer=0;
const picker=document.querySelector('#task-picker'),tourButton=document.querySelector('#tour');
function stopTour(){clearInterval(tourTimer);tourTimer=0;tourButton.setAttribute('aria-pressed','false');tourButton.textContent='Démo automatique';}
function setTheme(){root.dataset.theme=theme.value==='system'?(systemDark.matches?'dark':'light'):theme.value;}
theme.addEventListener('change',setTheme);systemDark.addEventListener('change',setTheme);setTheme();
const observer=new IntersectionObserver(entries=>{for(const e of entries)e.target.dataset.visible=String(e.isIntersecting);},{rootMargin:'0px'});
document.querySelectorAll('.art').forEach(el=>observer.observe(el));
function sync(){root.dataset.paused=String(paused||reduced.matches||document.hidden);pauseButton.querySelector('span').textContent=reduced.matches?'Mouvements réduits':paused?'Reprendre':'Mettre en pause';pauseButton.setAttribute('aria-pressed',String(paused||reduced.matches));pauseButton.disabled=reduced.matches;tourButton.disabled=reduced.matches;if(reduced.matches)stopTour();}
pauseButton.addEventListener('click',()=>{paused=!paused;sync();});reduced.addEventListener('change',sync);document.addEventListener('visibilitychange',sync);
function render(speak=true){
 const running=state==='running';
 document.querySelector('#task-title').textContent=state==='done'?'Travail terminé':state==='error'?'Un problème est survenu':state==='stop'?'Arrêt demandé':state==='unknown'?'Hermes travaille':current.title;
 document.querySelector('#running-label').textContent=state==='done'?'Terminé':state==='error'?'À vérifier':state==='stop'?'En attente':'En cours';
 document.querySelector('#reply').textContent=state==='done'?'C’est prêt.':state==='error'?'Je n’ai pas pu terminer cette demande.':'Je m’en occupe.';
 document.querySelector('#stage-caption').textContent=state==='done'?'Le résultat apparaîtra dans la conversation.':state==='error'?'Consulte les détails pour comprendre ce qui s’est passé.':state==='stop'?'En attente de la confirmation d’Hermes.':state==='unknown'?'Je traite ta demande.':(current.caption||captions[current.id]);
 phoneArt.dataset.scene=running?current.id:state==='unknown'?'think':'';
 phoneArt.innerHTML=running?current.svg:state==='unknown'?SCENES.find(scene=>scene.id==='think').svg:'<div class="result-symbol '+(state==='error'?'error':'')+'" aria-hidden="true">'+(state==='done'?'✓':state==='error'?'!':'Ⅱ')+'</div>';
 document.querySelector('#stop').hidden=state==='done'||state==='error';document.querySelector('#stop').disabled=state==='stop';document.querySelector('#prompt').textContent=current.prompt||prompts[current.id];picker.value=current.id;
 document.querySelectorAll('[data-task]').forEach(el=>el.setAttribute('aria-pressed',String(el.dataset.task===current.id)));document.querySelectorAll('[data-state]').forEach(el=>el.setAttribute('aria-pressed',String(el.dataset.state===state)));
 if(speak)announcement.textContent=document.querySelector('#task-title').textContent;sync();
}
function showPhone(){if(innerWidth<=760)document.querySelector('.phone').scrollIntoView({block:'start',behavior:reduced.matches?'instant':'smooth'});}
function choose(id){stopTour();current=SCENES.find(item=>item.id===id);state='running';render();showPhone();}
document.querySelectorAll('[data-task]').forEach(el=>el.addEventListener('click',()=>choose(el.dataset.task)));
picker.addEventListener('change',()=>choose(picker.value));
tourButton.addEventListener('click',()=>{if(tourTimer){stopTour();return;}state='running';paused=false;render(false);tourButton.setAttribute('aria-pressed','true');tourButton.textContent='Arrêter la démo';showPhone();tourTimer=setInterval(()=>{if(paused||reduced.matches||document.hidden)return;current=SCENES[(SCENES.indexOf(current)+1)%SCENES.length];state='running';render(false);const grid=document.querySelector('.task-grid'),card=grid.querySelector('[data-task='+current.id+']');if(card.offsetTop<grid.scrollTop+grid.offsetTop||card.offsetTop+card.offsetHeight>grid.scrollTop+grid.offsetTop+grid.clientHeight)grid.scrollTop=card.offsetTop-grid.offsetTop;},4600);});
document.querySelectorAll('[data-state]').forEach(el=>el.addEventListener('click',()=>{stopTour();state=el.dataset.state;render();}));document.querySelector('#stop').addEventListener('click',()=>{stopTour();state='stop';render();});render(false);
