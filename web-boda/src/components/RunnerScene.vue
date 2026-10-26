<script setup lang="ts">
import {onMounted,onUnmounted,ref,watch} from 'vue'
import type {Runner} from '../lib/runner'
const props=defineProps<{state:Runner;running:boolean;accessory?:string}>()
const canvas=ref<HTMLCanvasElement|null>(null)
let observer:ResizeObserver,ctx:CanvasRenderingContext2D|null=null,w=0,h=0,lane=1
const motion=matchMedia('(prefers-reduced-motion: reduce)').matches
function ellipse(x:number,y:number,rx:number,ry:number,color:string){ctx!.fillStyle=color;ctx!.beginPath();ctx!.ellipse(x,y,rx,ry,0,0,Math.PI*2);ctx!.fill()}
function poly(points:number[][],color:string){ctx!.fillStyle=color;ctx!.beginPath();points.forEach(([x,y],i)=>i?ctx!.lineTo(x!,y!):ctx!.moveTo(x!,y!));ctx!.closePath();ctx!.fill()}
function rect(x:number,y:number,width:number,height:number,color:string,r=0){ctx!.fillStyle=color;ctx!.beginPath();ctx!.roundRect(x,y,width,height,r);ctx!.fill()}
function stroke(points:number[][],color:string,width:number){ctx!.strokeStyle=color;ctx!.lineWidth=width;ctx!.lineCap='round';ctx!.lineJoin='round';ctx!.beginPath();points.forEach(([x,y],i)=>i?ctx!.lineTo(x!,y!):ctx!.moveTo(x!,y!));ctx!.stroke()}
function project(p:number,l:number){const d=Math.pow(Math.max(0,p),1.65);return {x:w*.5+(l-1)*w*.29*(.12+.88*d),y:h*(.23+.61*d),d}}
function tree(x:number,y:number,s:number,variant:number){ctx!.save();ctx!.translate(x,y);ctx!.scale(s,s);ellipse(0,0,32,9,'#173e3033');rect(-4,-47,8,47,'#99724f',3);ellipse(0,-66,32,36,variant?'#3e8b65':'#326f5d');ellipse(-15,-65,20,24,'#559d70');ellipse(11,-81,20,24,'#75b078');ellipse(-3,-91,17,12,'#8fbd83');if(variant){ellipse(-13,-66,4,4,'#f4c66d');ellipse(16,-83,4,4,'#eeb665')}ctx!.restore()}
function house(x:number,y:number,s:number,variant:number){ctx!.save();ctx!.translate(x,y);ctx!.scale(s,s);poly([[-37,0],[32,0],[45,-9],[-22,-15]],'#506b3f22');rect(-31,-82,62,82,variant?'#f3d9ad':'#fff2d6',3);poly([[31,0],[46,-10],[46,-83],[31,-82]],'#cfb592');poly([[-39,-80],[0,-111],[39,-80]],variant?'#ca8066':'#b77260');poly([[0,-111],[16,-117],[47,-88],[39,-80]],'#dd9b78');rect(-8,-32,18,32,'#578479',9);rect(-23,-65,15,19,'#538b8c',2);rect(10,-65,15,19,'#538b8c',2);stroke([[-15,-65],[-15,-46]],'#ffefcc',2);stroke([[17,-65],[17,-46]],'#ffefcc',2);rect(-25,-44,19,5,'#b87856',2);ellipse(-15,-46,10,4,'#6e9b61');ellipse(-18,-49,3,3,'#e3a8aa');ctx!.restore()}
function obstacle(kind:number,x:number,y:number,s:number){ctx!.save();ctx!.translate(x,y);ctx!.scale(s,s);ellipse(0,2,39,8,'#254a3333');
 if(kind===1){rect(-32,-44,9,47,'#976647',3);rect(23,-44,9,47,'#976647',3);poly([[-36,-47],[31,-47],[38,-53],[-29,-53]],'#fbe0a0');rect(-36,-47,68,30,'#e99b60',4);for(let i=-29;i<28;i+=20)poly([[i,-45],[i+11,-45],[i+2,-19],[i-9,-19]],'#fff0c3');rect(-38,-17,72,5,'#bf7552',2);ellipse(0,-32,11,11,'#fff9e4');stroke([[0,-26],[0,-37],[-4,-33],[0,-37],[4,-33]],'#9c654c',2.5)}
 else if(kind===2){rect(-37,-100,10,102,'#537d72',3);rect(27,-100,10,102,'#537d72',3);rect(-42,-103,84,37,'#5b9384',8);rect(-39,-103,78,6,'#8fbc9b',3);for(let i=-30;i<=30;i+=15){ellipse(i,-73,9,8,'#79a988');ellipse(i,-104,8,6,'#8bb889')}ellipse(0,-86,12,12,'#fff3d2');stroke([[0,-92],[0,-81],[-4,-85],[0,-81],[4,-85]],'#4a756b',2.5)}
 else{rect(-36,-71,72,70,'#36745b',14);poly([[36,0],[46,-13],[46,-68],[36,-71]],'#285d4d');rect(-34,-76,69,19,'#72aa75',12);for(let i=0;i<13;i++){const x=(i*23%63)-30,y=-20-(i*17%49);ellipse(x,y,10,8,i%2?'#518d63':'#669e6b')}for(const x of [-21,12]){ellipse(x,-39,5,5,'#f6d6b9');ellipse(x,-39,2,2,'#ce9f69')}}ctx!.restore()}
function coin(x:number,y:number,s:number,t:number){ctx!.save();ctx!.translate(x,y-18*s);ctx!.scale(s,s);const spin=motion?1:.6+.4*Math.abs(Math.cos(t*.08));ctx!.scale(spin,1);ellipse(0,0,12,14,'#a47430');ellipse(0,-2,11,13,'#ffcf58');ellipse(0,-2,7,9,'#edb341');ctx!.strokeStyle='#ffe694';ctx!.lineWidth=1.5;ctx!.beginPath();ctx!.ellipse(0,-2,8.5,10,0,0,Math.PI*2);ctx!.stroke();ctx!.fillStyle='#fff2bd';ctx!.font='bold 13px sans-serif';ctx!.textAlign='center';ctx!.fillText('✦',0,3);ctx!.restore()}
function puppy(x:number,y:number,size:number,t:number){const jumping=props.state.jump>0,duck=props.state.duck>0,jump=Math.sin(props.state.jump/42*Math.PI)*size*.9,bounce=props.running&&!motion?Math.sin(t*.52)*size*.035:0;ellipse(x,y+3,size*.39*(1-jump/(size*2)),size*.10,'#35533e30');ctx!.save();ctx!.translate(x,y-jump+bounce);ctx!.scale(size/100,size/100);if(duck)ctx!.scale(1.12,.58);const run=props.running&&!motion?Math.sin(t*.52)*8:0;
 ellipse(-22,-10+run,13,18,'#65412f');ellipse(22,-10-run,13,18,'#704733');ellipse(-22,-2+run,13,7,'#8a5940');ellipse(22,-2-run,13,7,'#986341');
 ellipse(0,-42,35,35,'#815136');ellipse(5,-46,28,32,'#a56e46');ellipse(0,-72,31,29,'#97633f');ellipse(4,-78,25,23,'#b58256');ellipse(-30,-70,12,25,'#6e4531');ellipse(30,-70,12,25,'#784c33');
 for(let i=0;i<32;i++){const px=(i*29%57)-28,py=-91+(i*19%68);if((px/34)**2+((py+59)/45)**2<1){ellipse(px,py,5.2,4.5,i%3?'#ad784e':'#bf8b5b');ctx!.strokeStyle='#81533655';ctx!.lineWidth=1;ctx!.beginPath();ctx!.arc(px,py,3.2,.5,4.8);ctx!.stroke()}}
 stroke([[0,-31],[10+Math.sin(t*.25)*6,-41],[15+Math.sin(t*.25)*6,-32],[8,-27]],'#d09b67',9);
 if(props.accessory==='bandana'||props.accessory==='bow'){poly([[-23,-61],[23,-61],[0,-42]],props.accessory==='bow'?'#a790bd':'#e78c6c');stroke([[-22,-61],[22,-61]],'#f6c8a1',3)}
 if(props.accessory==='collar')stroke([[-22,-61],[0,-57],[22,-61]],'#91bca2',5);
 if(props.accessory==='hat'){ellipse(0,-96,37,7,'#aa8150');rect(-25,-121,50,25,'#d8b67c',8);rect(-25,-104,50,6,'#8f6e53',1)}
 ctx!.restore();if(jumping){stroke([[x-size*.28,y-3],[x-size*.31,y-12]],'#ffffff99',2);stroke([[x+size*.28,y-3],[x+size*.31,y-12]],'#ffffff99',2)}
}
function draw(){if(!ctx||!w||!h)return;const s=props.state,t=s.tick,phase=Math.min(2,Math.floor(t/1200));ctx.clearRect(0,0,w,h);const sky=ctx.createLinearGradient(0,0,0,h*.5);sky.addColorStop(0,['#75c9df','#87cddc','#e7b797'][phase]!);sky.addColorStop(1,['#e0f3d9','#e9efd2','#ffddac'][phase]!);ctx.fillStyle=sky;ctx.fillRect(0,0,w,h);
 ellipse(w*.78,h*.14,w*.07,w*.07,'#fff0b8');ellipse(w*.78,h*.14,w*.10,w*.10,'#fff4c329');
 for(let i=0;i<4;i++){const x=((i*.31+(motion?0:t*.00006))%1.3)*w-w*.15,y=h*(.08+(i%2)*.08);ellipse(x,y,w*.10,h*.018,'#ffffffa0');ellipse(x+w*.03,y-h*.014,w*.045,h*.03,'#ffffffa0')}
 poly([[0,h*.24],[w*.12,h*.14],[w*.3,h*.22],[w*.46,h*.16],[w*.68,h*.23],[w*.86,h*.17],[w,h*.23],[w,h],[0,h]],'#83b793');
 poly([[0,h*.3],[w*.23,h*.23],[w*.48,h*.29],[w*.77,h*.23],[w,h*.3],[w,h],[0,h]],'#a6c58b');
 const ground=ctx.createLinearGradient(0,h*.24,0,h);ground.addColorStop(0,'#98bd79');ground.addColorStop(1,'#60966c');ctx.fillStyle=ground;ctx.fillRect(0,h*.29,w,h);
 poly([[w*.45,h*.23],[w*.55,h*.23],[w*1.15,h],[w*-.15,h]],'#ddd0a6');poly([[w*.455,h*.23],[w*.545,h*.23],[w*1.08,h],[w*-.08,h]],'#ebdbb1');
 for(let i=0;i<20;i++){const p=(i/20+(motion?0:t*.0019))%1;const d=p**1.65,y=h*(.23+.77*d),half=w*(.045+.535*d);stroke([[w*.5-half,y],[w*.5+half,y]],'#ceb987',Math.max(1,d*3));if(i%2===0)for(const side of [-1,1]){const x=w*.5+side*half;stroke([[x,y],[x+side*3,y+2]],'#ffefd0',Math.max(2,d*8))}}
 for(let i=0;i<16;i++){const p=(i/16+(motion?0:t*.0019))%1,q=Math.min(1,p+.026);for(const l of [.5,1.5]){const a=project(p,l),b=project(q,l);stroke([[a.x,a.y],[b.x,b.y]],'#fff7df',1+a.d*3)}}
 const items:Array<{depth:number;paint:()=>void}>=[];
 for(let i=0;i<12;i++){const p=(i/12+(motion?0:t*.0014))%1,point=project(p,1),scale=(.1+point.d*1.65)*Math.min(w/440,h/650);for(const side of [-1,1]){const x=w*.5+side*w*(.12+.57*point.d),y=point.y;items.push({depth:p,paint:()=>{if((i+phase)%4===0)house(x,y,scale,phase%2);else tree(x,y,scale,(i+phase)%2)}})}}
 for(const row of s.rows){const p=row.progress/10000,point=project(p,row.lane),c=project(p,row.coinLane),scale=(.16+point.d*1.02)*Math.min(w/350,h/440);items.push({depth:p,paint:()=>{obstacle(row.kind,point.x,point.y,scale);coin(c.x,c.y,scale,t+row.id)}})}
 lane+= (s.lane-lane)*(motion?1:.35);if(Math.abs(s.lane-lane)<.005)lane=s.lane;
 items.push({depth:1,paint:()=>puppy(project(1,lane).x,h*.84,Math.min(100,w*.21,h*.19),t)});
 items.sort((a,b)=>a.depth-b.depth).forEach(item=>item.paint());
 if(props.running&&!motion){ctx.globalAlpha=.25;for(let i=0;i<7;i++){const p=(i/7+t*.009)%1,x=w*(i%2?.96:.04),y=h*(.46+p*.5);stroke([[x,y],[x+(i%2?5:-5),y+8+p*25]],'#fff9dd',1.5)}ctx.globalAlpha=1}
 const shade=ctx.createLinearGradient(0,h*.87,0,h);shade.addColorStop(0,'#23493e00');shade.addColorStop(1,'#23493e50');ctx.fillStyle=shade;ctx.fillRect(0,h*.87,w,h*.13)
}
function resize(){const el=canvas.value;if(!el)return;const r=el.getBoundingClientRect(),dpr=Math.min(devicePixelRatio||1,2);w=r.width;h=r.height;el.width=Math.round(w*dpr);el.height=Math.round(h*dpr);ctx=el.getContext('2d');ctx?.setTransform(dpr,0,0,dpr,0,0);draw()}
watch(()=>[props.state.tick,props.running,props.accessory],draw,{flush:'post'})
onMounted(()=>{observer=new ResizeObserver(resize);if(canvas.value)observer.observe(canvas.value);resize()})
onUnmounted(()=>observer?.disconnect())
</script>
<template><canvas ref="canvas" class="surfer-scene" aria-hidden="true"/></template>
