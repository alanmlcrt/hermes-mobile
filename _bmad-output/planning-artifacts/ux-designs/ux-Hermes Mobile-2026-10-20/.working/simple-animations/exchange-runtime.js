const TOTAL=28800;
const PROMPT='Lis mes tâches via le MCP et mes notes, puis crée un résumé dans un fichier.';
const ANSWER='J’ai regroupé tes 3 tâches et les points utiles de tes notes.\n\nÀ retenir :\n• Finaliser le compte rendu\n• Vérifier le planning\n• Préparer la réunion\n\nLe résumé est prêt dans resume.md.';
const $=selector=>document.querySelector(selector);
const root=document.documentElement,thread=$('#thread'),seek=$('#seek'),playButton=$('#play'),draft=$('#draft'),log=$('#tool-log');
const reduced=matchMedia('(prefers-reduced-motion: reduce)'),systemDark=matchMedia('(prefers-color-scheme: dark)');
let elapsed=0,playing=!reduced.matches,frame=0,last=0,lastPhase='',lastChars=-1,stickToBottom=true;
function theme(){root.dataset.theme=$('#theme').value==='system'?(systemDark.matches?'dark':'light'):$('#theme').value;}
$('#theme').addEventListener('change',theme);systemDark.addEventListener('change',theme);theme();
function clock(ms){return String(Math.floor(ms/60000)).padStart(2,'0')+':'+String(Math.floor(ms/1000)%60).padStart(2,'0');}
function phaseAt(time){return PHASES.filter(phase=>time>=phase[1]).at(-1);}
function controls(){root.dataset.paused=String(!playing||document.hidden);playButton.textContent=elapsed>=TOTAL?'Rejouer':playing?'Mettre en pause':elapsed===0?'Lire la scène':'Reprendre';playButton.setAttribute('aria-pressed',String(playing));}
function scrollToEnd(){if(stickToBottom)requestAnimationFrame(()=>{thread.scrollTop=thread.scrollHeight;});}
function render(force=false){
 const phase=phaseAt(elapsed),changed=force||phase[0]!==lastPhase;
 root.dataset.phase=phase[0];
 const sent=elapsed>=3100;
 $('#user-message').hidden=!sent;$('#user-message').textContent=PROMPT;
 const draftLength=reduced.matches?PROMPT.length:Math.min(PROMPT.length,Math.floor(elapsed/2800*PROMPT.length));
 const draftText=sent?'':PROMPT.slice(0,draftLength);if(draft.value!==draftText)draft.value=draftText;
 $('#send').hidden=sent;$('#stop').hidden=elapsed<3500||elapsed>=27500;
 $('#assistant').hidden=elapsed<3500;
 log.hidden=elapsed<5400;
 const completed=TOOLS.filter(tool=>elapsed>=tool.end).length;
 $('#log-title').textContent=completed===TOOLS.length?'4 actions effectuées':'Actions d’Hermes';
 TOOLS.forEach((tool,index)=>{
  const row=$('[data-tool="'+index+'"]'),done=elapsed>=tool.end;
  row.hidden=elapsed<tool.start;row.dataset.state=done?'done':'active';
  const title=row.querySelector('.tool-title'),text=done?tool.done:tool.title;if(title.textContent!==text)title.textContent=text;
 });
 const initialThinking=elapsed>=3500&&elapsed<5400,finalThinking=elapsed>=18900&&elapsed<22400;
 $('#thinking').hidden=!(initialThinking||finalThinking);
 $('#thinking-label').textContent=finalThinking?'Je prépare ma réponse':'Je prends en compte ta demande';
 const answering=elapsed>=22400;
 $('#answer').hidden=!answering;
 const chars=!answering?0:reduced.matches?ANSWER.length:Math.min(ANSWER.length,Math.floor((elapsed-22400)/5100*ANSWER.length));
 if(chars!==lastChars){$('#answer-text').textContent=ANSWER.slice(0,chars);lastChars=chars;scrollToEnd();}
 $('#answer').dataset.streaming=String(answering&&chars<ANSWER.length);
 $('#file-result').hidden=elapsed<27500;
 if(changed){
  log.open=elapsed<18900;
  if(force)document.querySelectorAll('.tool-row').forEach(row=>row.open=false);
  document.querySelectorAll('[data-phase][data-at]').forEach(button=>{
   button.setAttribute('aria-current',button.dataset.phase===phase[0]?'step':'false');
   button.dataset.complete=String(Number(button.dataset.at)<phase[1]);
  });
  $('#announcement').textContent=phase[2];lastPhase=phase[0];scrollToEnd();
 }
 seek.value=String(elapsed);seek.setAttribute('aria-valuetext',clock(elapsed)+' sur '+clock(TOTAL));$('#time').textContent=clock(elapsed)+' / '+clock(TOTAL);
 controls();
}
function tick(now){
 frame=0;
 if(!playing||document.hidden){last=0;controls();return;}
 const dt=last?Math.min(now-last,250):0;last=now;
 elapsed=Math.min(TOTAL,elapsed+dt*Number($('#speed').value));
 if(elapsed>=TOTAL)playing=false;
 render();
 if(playing)frame=requestAnimationFrame(tick);
}
function schedule(){if(frame)cancelAnimationFrame(frame);frame=0;last=0;controls();if(playing&&!document.hidden)frame=requestAnimationFrame(tick);}
function jump(time){elapsed=Math.max(0,Math.min(TOTAL,time));playing=false;render(true);schedule();}
function replay(){elapsed=0;lastPhase='';lastChars=-1;playing=true;stickToBottom=true;thread.scrollTop=0;$('#file-preview').close();render(true);schedule();}
playButton.addEventListener('click',()=>{if(elapsed>=TOTAL){replay();return;}playing=!playing;controls();schedule();});
$('#replay').addEventListener('click',replay);
seek.addEventListener('input',()=>jump(Number(seek.value)));
document.querySelectorAll('[data-phase][data-at]').forEach(button=>button.addEventListener('click',()=>jump(Number(button.dataset.at))));
$('#next').addEventListener('click',()=>jump((PHASES.find(phase=>phase[1]>elapsed)||['done',TOTAL])[1]));
$('#send').addEventListener('click',()=>{elapsed=3100;playing=true;render(true);schedule();});
$('#stop').addEventListener('click',()=>{playing=false;controls();schedule();$('#announcement').textContent='Démonstration mise en pause';});
thread.addEventListener('scroll',()=>{stickToBottom=thread.scrollHeight-thread.scrollTop-thread.clientHeight<42;},{passive:true});
document.addEventListener('visibilitychange',schedule);
reduced.addEventListener('change',()=>{if(reduced.matches)playing=false;render(true);schedule();});
const observer=new IntersectionObserver(entries=>{for(const entry of entries)entry.target.dataset.visible=String(entry.isIntersecting);});
document.querySelectorAll('.art').forEach(art=>observer.observe(art));
$('#file-result').addEventListener('click',()=>{if(elapsed>=27500)$('#file-preview').showModal();});
$('#close-preview').addEventListener('click',()=>$('#file-preview').close());
render(true);schedule();
