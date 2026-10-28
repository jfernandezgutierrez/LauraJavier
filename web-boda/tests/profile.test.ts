import test from 'node:test'
import assert from 'node:assert/strict'
import {editableProfile} from '../src/lib/profile.ts'
test('profile updates exclude protected server fields even after loading a full database row',()=>{
 const row={id:'current-user',created_at:'2026-01-01',consent_at:'2026-01-01',full_name:' Javier ',alias:' Javi ',phone:' 123 ',email_updates:false,in_app_updates:true,leaderboard_visible:false}
 const payload=editableProfile(row)
 assert.deepEqual(payload,{full_name:'Javier',alias:'Javi',phone:'123',email_updates:false,in_app_updates:true,leaderboard_visible:false})
 assert.equal(row.full_name,' Javier ')
})
