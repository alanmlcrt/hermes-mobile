(async()=>{
 const wait=ms=>new Promise(resolve=>setTimeout(resolve,ms));
 const results=[];
 for(const id of ['research','read','create','connect']){
  document.querySelector('[data-task='+id+']').click();
  const moving=document.querySelector('#phone-art [data-motion]');
  const before=moving?.getAttribute('transform');await wait(180);
  results.push({task:id,selected:document.querySelector('#phone-art').dataset.scene===id,moving:before!==moving?.getAttribute('transform'),title:document.querySelector('#task-title').textContent});
 }
 document.querySelector('#pause').click();
 const moving=document.querySelector('#phone-art [data-motion]');
 const paused=moving.getAttribute('transform');await wait(180);
 results.push({pauseStable:paused===moving.getAttribute('transform')});
 document.querySelector('#pause').click();
 document.querySelector('[data-state=done]').click();
 results.push({doneNoAnimatedArt:!document.querySelector('#phone-art svg'),doneHidesStop:document.querySelector('#stop').hidden});
 document.querySelector('[data-state=error]').click();
 results.push({error:document.querySelector('#task-title').textContent.startsWith('Un probl')&&!!document.querySelector('.result-symbol.error')});
 document.querySelector('[data-state=unknown]').click();
 results.push({unknownFallback:!!document.querySelector('.generic-art')});
 document.querySelector('[data-state=running]').click();
 document.querySelector('#stop').click();
 results.push({stopUnconfirmed:document.querySelector('#stage-caption').textContent.includes('confirmation'),stopDisablesAction:document.querySelector('#stop').disabled});
 document.querySelector('[data-task=research]').click();
 results.push({viewport:innerWidth,documentWidth:document.documentElement.scrollWidth,externalAssets:document.querySelectorAll('script[src],link[href],img[src]').length});
 return results;
})()
