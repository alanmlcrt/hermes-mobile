import * as k from './vendor/iso-kit.mjs';

// Four illustrative Figure-scale machines, not a simulation of Hermes activity.
// All motion is translation of settled geometry; no per-frame path generation.
export const anatomyCSS = k.ISO_CSS;
const W = 600, H = 360;
const BASE = {x:-112,y:-62,w:224,d:124,r:7};
const P = k.fitProjection(k.boxCorners(BASE,-18,100),W,H,{pad:66,azimuth:43,elevation:32});
const projectedMove = ([x,y,z]) => {
  const a=k.iso([0,0,0],P),b=k.iso([x,y,z],P);
  return {dx:b[0]-a[0],dy:b[1]-a[1]};
};

function machine(id,title,hint) {
  let count=0;
  const stages={base:[],bed:[],moving:[],front:[]};
  const add=(layer,x,y,w,d,z,h,tone='mid',lit=false,r=1.2)=>{
    count++;
    const plan={x,y,w,d,r};
    const body=k.solidSvg(k.slabOf(plan,z,h,P,4,Math.min(.6,h/4)),{tone,lit});
    stages[layer].push({depth:k.depthOf([x+w/2,y+d/2,z+h/2],P),body});
    return {plan,top:z+h};
  };
  const line=(layer,path,tone='lo',free=false)=>stages[layer].push({depth:Infinity,body:k.lineSvg(path,{tone,free})});
  const screw=(layer,x,y,z)=>{
    add(layer,x-1.15,y-1.15,2.3,2.3,z,.9,'mid',false,.45);
    // Slot runs across the entire square screw-head top, edge to edge.
    line(layer,k.lineOnTop([x-1.15,y],[x+1.15,y],z+.9,P),'lo');
  };
  const corners=[[ -96,-46],[96,-46],[-96,46],[96,46]];
  for(const [x,y] of corners){add('base',x-7,y-7,14,14,-18,3,'lo');add('base',x-5,y-5,10,10,-15,5,'lo');}
  add('base',BASE.x,BASE.y,BASE.w,BASE.d,-10,10,'lo',false,BASE.r);
  line('base',k.planOutline(k.insetPlan(BASE,5),.05,P),'faint');
  for(const [x,y] of [[-103,-53],[103,-53],[-103,53],[103,53]])screw('base',x,y,0);
  add('base',-89,43,38,10,0,.8,'lo');
  screw('base',-85,48,.8);screw('base',-55,48,.8);
  for(const [a,b,y] of [[-80,-65,46],[-80,-61,48],[-80,-68,50]])line('base',k.lineOnTop([a,y],[b,y],.85,P),'lo',true);
  add('base',-35,46,116,6,0,.8,'lo');
  screw('base',-31,49,.8);screw('base',77,49,.8);
  const ticks=k.topTicks(-25,70,5,5,46,.85,[2,4],P);
  line('base',ticks.minor,'lo');line('base',ticks.major,'mid');

  function rails(axis='x'){
    if(axis==='x'){
      for(const y of [-43,37]){
        for(const x of [-85,76])add('bed',x,y-2,10,10,0,7,'mid');
        add('bed',-85,y,171,6,7,3,'mid');
        for(const x of [-91,86]){add('bed',x,y-2,6,10,0,14,'mid');screw('bed',x+3,y+3,14);}
      }
    }else{
      for(const x of [-78,72]){
        for(const y of [-43,35])add('bed',x-2,y,10,10,0,7,'mid');
        add('bed',x,-43,6,88,7,3,'mid');
        for(const y of [-49,45]){add('bed',x-2,y,10,6,0,14,'mid');screw('bed',x+3,y+3,14);}
      }
    }
  }
  function sheet(x=-52,y=-30,w=104,d=60,z=3){
    add('bed',x,y,w,d,z,1,'hi');
    // Printed text, not machine texture; free ends are intentional.
    for(let i=0;i<5;i++)line('bed',k.lineOnTop([x+8,y+10+i*8],[x+w-12-(i%2)*15,y+10+i*8],z+1.05,P),'lo',true);
  }
  function clips(){for(const [x,y] of [[-57,-31],[49,-31],[-57,23],[49,23]])add('bed',x,y,8,8,4,2,'mid');}
  function bushings(axis='x',x=-69,y=-43){
    if(axis==='x')for(const a of [x,x+10])for(const b of [-43,37])add('moving',a,b,8,6,10,4,'mid');
    else for(const a of [-78,72])for(const b of [y,y+10])add('moving',a,b,6,8,10,4,'mid');
  }
  function finish(move,period=4.8){
    const render=layer=>stages[layer].sort((a,b)=>a.depth-b.depth).map(p=>p.body).join('');
    const body=[`<path class="iso-halo" d="${k.haloOf(BASE,-18,10,P)}"/>`,render('base'),render('bed'),`<g data-motion="${id}">${render('moving')}</g>`,render('front')];
    const svg=k.figureSvg({width:W,height:H,label:hint,body});
    return {id,title,hint,svg,parts:count,motion:[{selector:`[data-motion="${id}"]`,...projectedMove(move),phase:0,period}]};
  }
  return {add,line,screw,rails,sheet,clips,bushings,finish};
}

function research(){
  const m=machine('research','Recherche en cours','Un chariot examine les fiches, une à une.');
  const {add,line,screw}=m;m.rails();
  add('bed',-72,-31,132,62,0,2,'lo');
  add('bed',-75,-34,138,3,0,6);add('bed',-75,31,138,3,0,6);
  add('bed',-75,-31,3,62,0,6);add('bed',60,-31,3,62,0,6);
  for(const x of [-66,-24,18]){
    add('bed',x,-26,34,52,2,.9,'hi');add('bed',x+4,-30,12,4,2,.9,'hi');
    for(let i=0;i<4;i++)line('bed',k.lineOnTop([x+5,-14+i*9],[x+27,-14+i*9],2.95,P),'lo',true);
  }
  m.bushings();add('moving',-69,-43,18,86,14,6);
  add('moving',-70,-11,20,22,20,13,'hi');
  add('moving',-71,-12,22,24,33,2,'mid');
  add('moving',-66,-7,12,14,35,.8,'hi',true);
  screw('moving',-68,-9,35);screw('moving',-52,9,35);
  return m.finish([111,0,0],5.8);
}

function read(){
  const m=machine('read','Lecture en cours','Une barre de lecture parcourt le document.');
  const {add,screw}=m;m.rails('y');
  add('bed',-60,-36,120,72,0,2,'lo');
  add('bed',-53,-30,106,60,2,.4,'hi');add('bed',-52,-29,104,58,2.4,.4,'hi');m.sheet(-51,-28,102,56,2.8);m.clips();
  m.bushings('y',0,-30);
  add('moving',-78,-30,156,18,14,6,'mid');
  add('moving',-70,-28,140,14,20,2,'hi');
  add('moving',-63,-24,126,6,22,.8,'hi',true);
  screw('moving',-74,-21,20);screw('moving',74,-21,20);
  return m.finish([0,51,0],5.2);
}

function create(){
  const m=machine('create','Création en cours','Une plume sur portique trace sur la feuille.');
  const {add,screw,line}=m;m.rails();
  add('bed',-70,-33,140,66,0,3,'lo');m.sheet(-65,-28,130,56,3);m.clips();m.bushings();
  for(const y of [-43,37]){
    add('moving',-69,y,18,6,14,45,'mid');
    add('moving',-72,y-1,24,8,59,2,'mid');
    screw('moving',-68,y+2,61);screw('moving',-52,y+2,61);
  }
  add('moving',-69,-43,18,86,61,5,'hi');
  add('moving',-69,-10,18,20,53,8,'mid');
  add('moving',-63,-3,6,6,10,43,'hi',true);
  add('moving',-64,-4,8,8,8,2,'mid');
  add('moving',-61,-1,2,2,4,4,'hi');
  // Printed illustrative line on paper; no purported generated artifact.
  line('bed',k.lineOnTop([-49,0],[42,0],4.05,P),'lo',true);
  return m.finish([108,0,0],6.2);
}

function connect(){
  const m=machine('connect','Connexion en cours','Un connecteur guidé s’approche de sa prise.');
  const {add,screw}=m;m.rails();
  // Receiver supported across the same bench, fully clear of the moving plug.
  add('bed',-76,-27,51,54,0,10,'mid');
  add('bed',-70,-23,45,46,10,28,'hi');
  add('bed',-25,-16,1,32,16,16,'lo');
  add('bed',-25,-23,5,7,10,28,'mid');add('bed',-25,16,5,7,10,28,'mid');
  for(const [x,y] of [[-72,-24],[-72,24],[-29,-24],[-29,24]])screw('bed',x,y,10);
  for(const x of [20,44])for(const y of [-43,37])add('moving',x,y,8,6,10,4,'mid');
  add('moving',20,-43,32,86,14,4,'mid');
  add('moving',20,-16,35,32,18,16,'hi',true);
  add('moving',20,-22,35,6,18,5,'mid');add('moving',20,16,35,6,18,5,'mid');
  add('moving',42,-12,10,24,34,4,'mid');
  screw('moving',45,-8,38);screw('moving',45,8,38);
  // Stroke leaves at least 3 world units between housing and receiver lips.
  return m.finish([-37,0,0],4.6);
}

export const scenes=[research(),read(),create(),connect()];
