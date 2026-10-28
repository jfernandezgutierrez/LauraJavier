import test from 'node:test'
import assert from 'node:assert/strict'
import {newSprint,stepSprint,replaySprint,sprintReward,sprintSpeed,sprintKey} from '../src/lib/sprint.ts'

test('Sprint: ground collision ends a run and stops subsequent updates',()=>{
 const s=newSprint(123456);while(!s.dead)stepSprint(s)
 assert.ok(s.tick<300);assert.equal(s.cleared,0)
 const snapshot=structuredClone(s);stepSprint(s,true);assert.deepEqual(s,snapshot)
})
test('Sprint: one jump lands after 41 ticks; airborne presses cannot double-jump',()=>{
 const a=newSprint(1),b=newSprint(1);stepSprint(a,true);stepSprint(b,true)
 for(let i=1;i<41;i++){stepSprint(a);stepSprint(b,true);assert.equal(a.y,b.y)}
 assert.equal(a.y,0);assert.equal(a.velocity,0)
})
test('Sprint: collision uses both obstacle width and actual jump height',()=>{
 const s=newSprint(1);s.obstacles=[{id:0,x:1300,width:640,height:650,kind:1,passed:false}]
 stepSprint(s,true);assert.equal(s.dead,true)
 const high=newSprint(1);high.y=900;high.obstacles=[{id:0,x:1300,width:640,height:650,kind:1,passed:false}]
 stepSprint(high);assert.equal(high.dead,false)
})
test('Sprint: obstacles count once, speed grows and controls include Space',()=>{
 const s=newSprint(1);s.obstacles=[{id:0,x:500,width:380,height:450,kind:0,passed:false}]
 stepSprint(s);stepSprint(s);assert.equal(s.cleared,1)
 assert.equal(sprintSpeed(1),50);assert.equal(sprintSpeed(3599),85)
 assert.equal(sprintKey('Space'),true);assert.equal(sprintKey('ArrowUp'),true);assert.equal(sprintKey('KeyW'),true);assert.equal(sprintKey('ArrowDown'),false)
})
// Jump roughly 10 frames before the leading edge reaches the dog's hitbox.
export function route(seed:number){const s=newSprint(seed),inputs:number[]=[];while(!s.dead){const next=s.obstacles.find(o=>o.x+o.width>900);const jump=s.y===0&&!!next&&next.x-1340<sprintSpeed(s.tick+1)*10;if(jump)inputs.push(s.tick+1);stepSprint(s,jump)}return {s,inputs}}
test('Sprint: seeded obstacles admit a full run and replay exactly on varied courses',()=>{
 for(const seed of [1,42,123456,2147483645]){const {s,inputs}=route(seed);assert.equal(s.tick,3600);assert.ok(s.cleared>20);assert.deepEqual(replaySprint(seed,inputs,3600),s);const r=sprintReward(s);assert.ok(r.coins<=60&&r.xp<=90);assert.ok(r.score>600)}
})
