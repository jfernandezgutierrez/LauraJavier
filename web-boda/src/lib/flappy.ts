// Integer hundredths of a pixel keep browser and Postgres replays identical.
export const MAX_TICKS=3600, STEP_MS=1000/60
export interface Gate {x:number;center:number;passed:boolean}
export interface Flight {tick:number;y:number;velocity:number;seed:number;score:number;dead:boolean;gates:Gate[]}
export function newFlight(seed:number):Flight{return {tick:0,y:24000,velocity:0,seed,score:0,dead:false,gates:[]}}
export function stepFlight(s:Flight,flap:boolean):Flight{
 if(s.dead)return s
 s.tick++
 if(flap)s.velocity=-520
 s.velocity=Math.min(800,s.velocity+32);s.y+=s.velocity
 if(s.tick>=60&&(s.tick-60)%110===0){s.seed=s.seed*48271%2147483647;s.gates.push({x:40000,center:13000+s.seed%21000,passed:false})}
 const speed=220+Math.min(100,Math.floor(s.tick/600)*15)
 for(const g of s.gates){g.x-=speed
  if(g.x<10200&&g.x+5200>7400&&(s.y-1400<g.center-7200||s.y+1400>g.center+7200))s.dead=true
  if(!g.passed&&g.x+5200<7400){g.passed=true;s.score++}
 }
 s.gates=s.gates.filter(g=>g.x>-6000)
 if(s.y<1400||s.y>46600||s.tick>=MAX_TICKS)s.dead=true
 return s
}
export function replay(seed:number,taps:number[],ticks:number){const s=newFlight(seed);const inputs=new Set(taps);while(!s.dead&&s.tick<ticks)stepFlight(s,inputs.has(s.tick+1));return s}
