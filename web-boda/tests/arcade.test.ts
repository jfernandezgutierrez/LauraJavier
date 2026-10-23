import test from 'node:test'
import assert from 'node:assert/strict'
import {catchScore,memoryStep} from '../src/lib/arcade.ts'
test('catch rewards depend on collected lanes, including misses',()=>{
 assert.equal(catchScore([0,2,1,0],[0,1,1,2]),2)
 assert.equal(catchScore([1,1],[0,0]),0)
})
test('memory keeps only matching pairs without mutating the previous state',()=>{
 const previous:number[]=[]
 assert.deepEqual(memoryStep([0,1,1,0],previous,0,1),[])
 assert.deepEqual(memoryStep([0,1,1,0],previous,0,3),[0,3])
 assert.deepEqual(previous,[])
})
test('memory rejects repeated, matched, out of bounds and fractional cards',()=>{
 for(const pair of [[0,0],[-1,2],[0,4],[0.5,1]])assert.throws(()=>memoryStep([0,1,1,0],[],pair[0]!,pair[1]!))
 assert.throws(()=>memoryStep([0,1,1,0],[0,3],0,3))
})
