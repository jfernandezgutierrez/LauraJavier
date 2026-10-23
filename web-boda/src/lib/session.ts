import { ref } from 'vue'
import type { User } from '@supabase/supabase-js'
import { db, fail } from './supabase'
import type { Profile, Invitation } from './types'
export const user=ref<User|null>(null), profile=ref<Profile|null>(null), invitation=ref<Invitation|null>(null), isAdmin=ref(false), authReady=ref(false)
let loadVersion=0
export async function refreshProfile(){
 const version=++loadVersion
 if(!user.value){profile.value=null;invitation.value=null;isAdmin.value=false;return}
 const id=user.value.id
 const [p,i,a]=await Promise.all([db.from('wedding_profiles').select('*').eq('id',id).maybeSingle(),db.from('wedding_invitations').select('*').eq('user_id',id).maybeSingle(),db.rpc('wedding_is_admin')])
 if(version!==loadVersion||user.value?.id!==id)return
 fail(p.error);fail(i.error);fail(a.error);profile.value=p.data;invitation.value=i.data;isAdmin.value=!!a.data
}
export async function initializeAuth(){
 db.auth.onAuthStateChange((event,session)=>{user.value=session?.user??null;queueMicrotask(()=>{void refreshProfile().catch(console.error)});if(event==='PASSWORD_RECOVERY')window.dispatchEvent(new Event('password-recovery'))})
 const {data,error}=await db.auth.getSession();fail(error);user.value=data.session?.user??null
 await refreshProfile();authReady.value=true
}
export async function logout(){const {error}=await db.auth.signOut();fail(error);user.value=null;await refreshProfile()}
