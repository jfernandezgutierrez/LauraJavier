import test from 'node:test'
import assert from 'node:assert/strict'
import {newPet,demoAction} from '../src/lib/pet.ts'
test('food costs coins and improves hunger without mutating input',()=>{const p=newPet(),r=demoAction(p,'feed');assert.equal(r.coins,54);assert.equal(r.hunger,90);assert.equal(r.xp,8);assert.equal(p.coins,60)})
test('cannot buy food without enough coins or overfeed',()=>{assert.throws(()=>demoAction({...newPet(),coins:0},'feed'));assert.throws(()=>demoAction({...newPet(),hunger:100},'feed'))})
test('play rewards server-equivalent coins and consumes energy',()=>{const p=demoAction(newPet(),'play');assert.equal(p.energy,67);assert.equal(p.coins,68);assert.equal(p.xp,12);assert.equal(p.hygiene,51)})
test('sleep blocks care actions until waking',()=>{const p=demoAction(newPet(),'sleep');assert.equal(p.sleeping,true);assert.throws(()=>demoAction(p,'feed'));assert.throws(()=>demoAction(p,'play'));assert.equal(demoAction(p,'wake').sleeping,false);assert.equal(p.xp,0)})
test('cannot play without energy or gain care xp from a full stat',()=>{assert.throws(()=>demoAction({...newPet(),energy:0},'play'));assert.throws(()=>demoAction({...newPet(),happiness:100},'pet'));assert.throws(()=>demoAction({...newPet(),hygiene:100},'wash'))})
test('one bath cleans even a completely dirty dog and cannot grant repeated XP',()=>{
 for(const hygiene of [0,4,35,39,60,94]){
  const before={...newPet(),hygiene},after=demoAction(before,'wash')
  assert.equal(after.hygiene,100);assert.equal(after.xp-before.xp,8)
  assert.equal(after.care_count-before.care_count,1);assert.equal(after.coins,before.coins)
  assert.equal(before.hygiene,hygiene);assert.throws(()=>demoAction(after,'wash'))
 }
})
