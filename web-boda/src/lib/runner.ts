// Fixed 60 Hz integer simulation, replayed by Postgres before awarding anything.
export const RUN_TICKS=3600,RUN_STEP=1000/60
export type RunAction=0|1|2|3|4 // none, left, right, jump, duck
export interface RunRow {id:number;progress:number;lane:number;kind:number;coinLane:number}
export interface Runner {tick:number;seed:number;lane:number;jump:number;duck:number;tokens:number;cleared:number;dead:boolean;rows:RunRow[]}
export function newRunner(seed:number):Runner{return {tick:0,seed,lane:1,jump:0,duck:0,tokens:0,cleared:0,dead:false,rows:[]}}
export function stepRunner(s:Runner,action:RunAction=0):Runner{
 if(s.dead)return s
 s.tick++;s.jump=Math.max(0,s.jump-1);s.duck=Math.max(0,s.duck-1)
 if(action===1)s.lane=Math.max(0,s.lane-1)
 if(action===2)s.lane=Math.min(2,s.lane+1)
 if(action===3&&!s.jump&&!s.duck)s.jump=42
 if(action===4&&!s.jump&&!s.duck)s.duck=42
 if((s.tick-1)%90===0){
  s.seed=s.seed*48271%2147483647;const lane=s.seed%3
  s.seed=s.seed*48271%2147483647;const kind=1+s.seed%3
  s.seed=s.seed*48271%2147483647;s.rows.push({id:s.tick,progress:0,lane,kind,coinLane:s.seed%3})
 }
 const speed=55+Math.min(35,Math.floor(s.tick/600)*7)
 for(const row of s.rows){row.progress+=speed;if(row.progress>=10000){
  if(s.lane===row.lane&&!(row.kind===1&&s.jump>0)&&!(row.kind===2&&s.duck>0))s.dead=true
  if(!s.dead){s.cleared++;if(s.lane===row.coinLane)s.tokens++}
 }}
 s.rows=s.rows.filter(row=>row.progress<10000)
 if(s.tick>=RUN_TICKS)s.dead=true
 return s
}
export function runScore(s:Runner){return Math.floor(s.tick/6)+s.tokens*20}
export function runReward(s:Runner){return {score:runScore(s),coins:Math.min(60,s.tokens*2+Math.floor(s.tick/600)),xp:Math.min(90,Math.floor(s.tick/60)+s.tokens),tokens:s.tokens}}
export function replayRunner(seed:number,inputs:number[],ticks:number){const s=newRunner(seed);let i=0;while(!s.dead&&s.tick<ticks){const event=inputs[i];let action:RunAction=0;if(event!==undefined&&Math.floor(event/10)===s.tick+1){action=(event%10) as RunAction;i++}stepRunner(s,action)}return s}
export function runnerKey(code:string):RunAction{return ({ArrowLeft:1,KeyA:1,ArrowRight:2,KeyD:2,ArrowUp:3,KeyW:3,Space:3,ArrowDown:4,KeyS:4} as Record<string,RunAction>)[code]??0}
export function swipeAction(dx:number,dy:number):RunAction{if(Math.max(Math.abs(dx),Math.abs(dy))<24)return 0;return Math.abs(dx)>Math.abs(dy)?dx<0?1:2:dy<0?3:4}
