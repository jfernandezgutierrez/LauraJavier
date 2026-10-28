<script setup lang="ts">
import {computed,nextTick,onMounted,onUnmounted,ref,watch} from 'vue'
import {ArrowLeft,ArrowUp,Coins,Footprints,Pause,Play,Trophy} from 'lucide-vue-next'
import DogSprite from './DogSprite.vue'
import SprintScene from './SprintScene.vue'
import {db,fail,friendly} from '../lib/supabase'
import {user} from '../lib/session'
import {newSprint,stepSprint,sprintScore,sprintKey,SPRINT_STEP,SPRINT_TICKS} from '../lib/sprint'
const props=defineProps<{disabled?:boolean;accessory?:string}>(),emit=defineEmits<{updated:[];active:[value:boolean]}>()
const shell=ref<HTMLElement|null>(null),field=ref<HTMLElement|null>(null)
const mode=ref<'menu'|'ready'|'playing'|'paused'|'result'>('menu'),state=ref(newSprint(1)),busy=ref(false),error=ref(''),best=ref(0)
const ranking=ref<{alias:string;score:number}[]>([]),showRanks=ref(false),award=ref<{score:number;coins:number;xp:number;best:number;cleared:number}|null>(null)
let run:{id:string;seed:number}|null=null,inputs:number[]=[],queued=false,raf=0,lastTime=0,accumulator=0,owner='',alive=true
const score=computed(()=>sprintScore(state.value))
function focus(){field.value?.focus({preventScroll:true})}
async function records(){const id=user.value?.id;const {data,error:e}=await db.rpc('wedding_sprint_records');if(!e&&alive&&id===user.value?.id){best.value=data.best;ranking.value=data.ranking}}
async function start(){
 if(busy.value||props.disabled||!user.value)return
 busy.value=true;error.value='';owner=user.value.id
 try{const {data,error:e}=await db.rpc('wedding_sprint_start');fail(e);if(!alive||owner!==user.value?.id)return;run=data;state.value=newSprint(data.seed);inputs=[];queued=false;award.value=null;mode.value='ready';emit('active',true);emit('updated');await nextTick();shell.value?.scrollIntoView({block:'start',behavior:'instant'});focus()}
 catch(e){if(alive)error.value=friendly(e)}finally{busy.value=false}
}
function schedule(){lastTime=performance.now();accumulator=0;raf=requestAnimationFrame(frame)}
function begin(){if(mode.value!=='ready')return;mode.value='playing';focus();schedule()}
function jump(){if(mode.value==='ready')begin();if(mode.value==='playing'&&state.value.y===0){queued=true;focus()}}
function frame(time:number){
 if(mode.value!=='playing')return
 const delta=time-lastTime;lastTime=time;if(delta>350){pause();return}accumulator+=delta
 while(accumulator>=SPRINT_STEP&&!state.value.dead){const pressed=queued&&state.value.y===0;queued=false;if(pressed)inputs.push(state.value.tick+1);stepSprint(state.value,pressed);accumulator-=SPRINT_STEP}
 if(state.value.dead){mode.value='result';void finish();return}raf=requestAnimationFrame(frame)
}
function pause(){if(mode.value!=='playing')return;cancelAnimationFrame(raf);queued=false;mode.value='paused'}
function resume(){if(mode.value!=='paused')return;mode.value='playing';focus();schedule()}
async function finish(){
 if(!run||busy.value||award.value)return;busy.value=true;error.value=''
 try{const {data,error:e}=await db.rpc('wedding_sprint_finish',{run_id:run.id,inputs,ticks:state.value.tick});fail(e);if(!alive||owner!==user.value?.id)return;award.value=data;best.value=data.best;emit('updated');void records()}
 catch(e){if(alive)error.value=friendly(e)}finally{busy.value=false}
}
function leave(){cancelAnimationFrame(raf);queued=false;mode.value='menu';run=null;emit('active',false)}
function key(e:KeyboardEvent){
 if(!['ready','playing','paused'].includes(mode.value)||e.ctrlKey||e.metaKey||e.altKey)return
 const target=e.target as HTMLElement|null
 if(target?.isContentEditable||target?.closest('input,textarea,select,[role="dialog"]'))return
 if(target&&target!==document.body&&!shell.value?.contains(target))return
 if(['Escape','KeyP'].includes(e.code)){e.preventDefault();e.stopPropagation();if(!e.repeat){if(mode.value==='playing')pause();else if(mode.value==='paused')resume()}return}
 if(sprintKey(e.code)&&mode.value!=='paused'){e.preventDefault();e.stopPropagation();if(!e.repeat)jump()}
}
function hidden(){if(document.hidden)pause()}
watch(()=>user.value?.id,()=>{leave();award.value=null;best.value=0;ranking.value=[]})
onMounted(()=>{void records();window.addEventListener('keydown',key,true);document.addEventListener('visibilitychange',hidden);window.addEventListener('huellas-viewport-change',pause)})
onUnmounted(()=>{alive=false;cancelAnimationFrame(raf);window.removeEventListener('keydown',key,true);document.removeEventListener('visibilitychange',hidden);window.removeEventListener('huellas-viewport-change',pause);emit('active',false)})
</script>
<template><section ref="shell" class="flappy-game runner-game sprint-game" :class="{'runner-active':mode!=='menu'}">
 <template v-if="mode==='menu'">
  <button class="flappy-card sprint-card" :disabled="disabled||busy" @click="start"><div class="flight-cover sprint-cover"><DogSprite mood="playing"/><i>SALTA &amp; CORRE</i></div><span><b>Huellas Sprint</b><small>Un salto. Otro más. ¡Que nada os pare!</small><em>{{busy?'Preparando…':'¡Vamos a saltar! →'}}</em></span></button>
  <div class="flight-record"><Trophy :size="16"/> Tu récord: {{best}} puntos <button @click="showRanks=!showRanks">Clasificación Sprint</button></div>
  <p class="arcade-note">Salta troncos y rocas mientras el paseo se acelera.<br/>Espacio / ↑ en PC · Toca la pantalla en móvil.<br/>3 energía + 2 comida por partida · Hasta 60 s · Máximo 60 monedas y 90 XP.</p>
  <div v-if="showRanks" class="flappy-ranking"><p v-if="!ranking.length">Sé el primero. Activa la clasificación con alias desde tu perfil para aparecer.</p><ol v-else><li v-for="(r,i) in ranking" :key="i">{{r.alias}} <b>{{r.score}} puntos</b></li></ol></div><p v-if="error" class="pet-error" role="alert">{{error}}</p>
 </template>
 <template v-else>
  <header class="flight-toolbar"><button v-if="mode==='result'" :disabled="busy" @click="leave" aria-label="Volver al patio desde Sprint"><ArrowLeft :size="20"/></button><Footprints v-else :size="21"/><b>Huellas Sprint<small>{{state.tick<1800?'Un paseo contigo':'Bajo las estrellas'}}</small></b><span>{{Math.floor(state.tick/60)}} / 60 s</span><button v-if="mode==='playing'" @click="pause" aria-label="Pausar Sprint"><Pause :size="20"/></button></header>
  <div ref="field" class="flight-field runner-field sprint-field" tabindex="0" role="application" aria-label="Huellas Sprint. Toca, pulsa Espacio o flecha arriba para saltar. P para pausar." @pointerdown.prevent="e=>{if(e.isPrimary&&e.button===0)jump()}">
   <SprintScene :state="state" :running="mode==='playing'" :accessory="accessory"/>
   <div class="sprint-hud"><span><small>PUNTOS</small><b>{{String(score).padStart(5,'0')}}</b></span><span><small>RÉCORD</small><b>{{String(Math.max(best,score)).padStart(5,'0')}}</b></span></div>
   <div v-if="mode==='playing'&&state.tick<240" class="sprint-tip">Espacio / ↑ · Toca para saltar</div>
   <div v-if="mode==='ready'" class="flight-overlay" @pointerdown.stop><div><span class="surfer-eyebrow">UN BOTÓN · MIL SALTOS</span><h4>¡Que empiece el paseo!</h4><p>Salta troncos y rocas.<br/>Cada obstáculo superado suma premios.</p><button @click="begin">¡A saltar!</button><button class="flight-secondary" @click="leave">Volver al patio</button></div></div>
   <div v-else-if="mode==='paused'" class="flight-overlay" @pointerdown.stop><div><Pause :size="28"/><h4>Un respiro</h4><p>El paseo está en pausa.</p><button @click="resume"><Play :size="16"/> Continuar</button><button class="flight-secondary" @click="leave">Salir sin recompensa</button></div></div>
   <div v-else-if="mode==='result'" class="flight-overlay" @pointerdown.stop><div><Trophy :size="28"/><h4>{{state.tick===SPRINT_TICKS?'¡Paseo completado!':'¡Un salto más!'}}</h4><p class="result-score">{{score}}<small>puntos · {{state.cleared}} obstáculos superados</small></p><p v-if="busy" role="status">Guardando tu paseo…</p><div v-else-if="award" class="flight-prizes"><span><Coins :size="16"/> +{{award.coins}}</span><span>✦ +{{award.xp}} XP</span></div><p v-if="award">Tu récord: {{best}} puntos</p><p v-if="error" class="flight-error" role="alert">{{error}}</p><button v-if="error&&!award" :disabled="busy" @click="finish">Reintentar guardar</button><button v-else :disabled="busy||disabled" @click="start">Otro paseo</button><button :disabled="busy" class="flight-secondary" @click="leave">Volver al patio</button></div></div>
  </div>
  <div class="runner-buttons sprint-buttons"><button :disabled="mode!=='playing'" @pointerdown.prevent="e=>{if(e.isPrimary&&e.button===0)jump()}" @click="e=>{if(e.detail===0)jump()}"><ArrowUp :size="22"/><span>Saltar</span></button></div>
  <div class="game-controls-guide"><span><b>PC</b> <kbd>Espacio</kbd> / <kbd>↑</kbd> saltar · <kbd>P</kbd> pausa</span><span><b>Móvil</b> Toca el paisaje o el botón Saltar.</span></div>
 </template>
</section></template>
