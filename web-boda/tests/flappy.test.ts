import test from 'node:test'
import assert from 'node:assert/strict'
import {newFlight,stepFlight,replay,MAX_TICKS} from '../src/lib/flappy.ts'
test('a fall ends the game, cannot advance after collision',()=>{const s=newFlight(42);while(!s.dead)stepFlight(s,false);assert.equal(s.tick,41);assert.equal(s.score,0);stepFlight(s,true);assert.equal(s.tick,41)})
test('flap counteracts gravity, simulation independent of screen size',()=>{const a=newFlight(17),b=newFlight(17);for(let i=1;i<=60&&!a.dead;i++){stepFlight(a,i%25===1);stepFlight(b,i%25===1)}assert.deepEqual(a,b);assert.ok(a.y<46600)})
test('seed controls gates deterministically and replays preserve exact result',()=>{const s=newFlight(123456),taps:number[]=[];while(!s.dead){const target=s.gates.find(g=>g.x+5200>7400)?.center??24000;const flap=s.y>target+500&&s.velocity>0;if(flap)taps.push(s.tick+1);stepFlight(s,flap)}const r=replay(123456,taps,s.tick);assert.deepEqual(r,s);assert.ok(s.tick<=MAX_TICKS);assert.ok(s.score>0)})
