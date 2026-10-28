// Integer physics at 60 Hz. The database replays these same jumps before awarding prizes.
export const SPRINT_TICKS=3600,SPRINT_STEP=1000/60
export interface SprintObstacle {id:number;x:number;width:number;height:number;kind:number;passed:boolean}
export interface Sprint {tick:number;seed:number;y:number;velocity:number;next:number;distance:number;cleared:number;dead:boolean;obstacles:SprintObstacle[]}
export function newSprint(seed:number):Sprint{return {tick:0,seed,y:0,velocity:0,next:60,distance:0,cleared:0,dead:false,obstacles:[]}}
export function sprintSpeed(tick:number){return 50+Math.min(35,Math.floor(tick/600)*7)}
export function stepSprint(s:Sprint,jump=false):Sprint{
 if(s.dead)return s
 s.tick++
 if(jump&&s.y===0)s.velocity=140
 s.y=Math.max(0,s.y+s.velocity);s.velocity=s.y>0?s.velocity-7:0
 if(s.tick===s.next){
  s.seed=s.seed*48271%2147483647;const kind=s.seed%3
  s.obstacles.push({id:s.tick,x:6500,width:kind===2?640:380,height:kind===1?650:450,kind,passed:false})
  s.seed=s.seed*48271%2147483647;s.next=s.tick+85+s.seed%46
 }
 const speed=sprintSpeed(s.tick);s.distance+=speed
 for(const o of s.obstacles){
  o.x-=speed
  if(o.x<1340&&o.x+o.width>900&&s.y+70<o.height)s.dead=true
  if(!s.dead&&!o.passed&&o.x+o.width<=900){o.passed=true;s.cleared++}
 }
 s.obstacles=s.obstacles.filter(o=>o.x+o.width>0)
 if(s.tick>=SPRINT_TICKS)s.dead=true
 return s
}
export function sprintScore(s:Sprint){return Math.floor(s.tick/6)+s.cleared*10}
export function sprintReward(s:Sprint){return {score:sprintScore(s),coins:Math.min(60,s.cleared*2+Math.floor(s.tick/600)),xp:Math.min(90,Math.floor(s.tick/60)+s.cleared),cleared:s.cleared}}
export function replaySprint(seed:number,inputs:number[],ticks:number){const s=newSprint(seed);let i=0;while(!s.dead&&s.tick<ticks){const jump=inputs[i]===s.tick+1;if(jump)i++;stepSprint(s,jump)}return s}
export function sprintKey(code:string){return ['Space','ArrowUp','KeyW'].includes(code)}
