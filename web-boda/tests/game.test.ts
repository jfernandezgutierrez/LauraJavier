import test from 'node:test'
import assert from 'node:assert/strict'
import {replay,nextPosition,scoreFor} from '../src/lib/game.ts'
test('valid route collects both rings and reaches the couple',()=>{const r=replay('UUUURURRRRRDDDDRUUUU');assert.equal(r.won,true);assert.equal(r.score,1600)})
test('cannot walk through hedge or outside the garden',()=>{assert.equal(nextPosition(2,2,'R'),null);assert.equal(nextPosition(0,5,'D'),null);assert.throws(()=>replay('L'));assert.throws(()=>replay('XXX'))})
test('reaching the goal without rings is not a win',()=>assert.equal(replay('UUUUURRRRRRR').won,false))
test('extra moves reduce score and score has a floor',()=>{assert.ok(scoreFor(25)<scoreFor(20));assert.equal(scoreFor(300),100)})
