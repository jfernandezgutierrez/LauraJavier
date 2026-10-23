<script setup lang="ts">
import {ref,computed,onUnmounted,nextTick} from 'vue'
import {Coins,Sparkles,ArrowLeft,Gamepad2} from 'lucide-vue-next'
import VirtualDog from './VirtualDog.vue'
import {db,fail,friendly} from '../lib/supabase'
import {ROUND_MS,CATCH_ROUNDS,MEMORY_ICONS,catchScore,memoryStep,type Challenge,type GameKind,type GameReward} from '../lib/arcade'
defineProps<{disabled:boolean}>()
const emit=defineEmits<{updated:[]}>()
const challenge=ref<Challenge|null>(null),phase=ref<'menu'|'ready'|'playing'|'result'>('menu'),busy=ref(false),error=ref(''),result=ref<GameReward|null>(null)
const boardElement=ref<HTMLElement|null>(null)
const moves=ref<number[]>([]),lane=ref(1),round=ref(0),progress=ref(0),matched=ref<number[]>([]),flipped=ref<number[]>([]),locked=ref(false),elapsed=ref(0)
let timer:ReturnType<typeof setInterval>|undefined,flipTimer:ReturnType<typeof setTimeout>|undefined,alive=true,lastTick=0,roundTime=0
const score=computed(()=>challenge.value?.kind==='catch'?catchScore(challenge.value.board,moves.value):matched.value.length/2)
const done=computed(()=>challenge.value?.kind==='catch'?round.value>=CATCH_ROUNDS:matched.value.length===12||moves.value.length>=48)
async function start(kind:GameKind){if(busy.value)return;busy.value=true;error.value='';try{
 const {data,error:e}=await db.rpc('wedding_arcade_start',{game_kind:kind});fail(e);if(!alive)return
 challenge.value=data;phase.value='ready';moves.value=[];matched.value=[];flipped.value=[];round.value=0;progress.value=0;elapsed.value=0;result.value=null;emit('updated')
 }catch(e){error.value=friendly(e)}finally{busy.value=false}}
function begin(){phase.value='playing';void nextTick(()=>boardElement.value?.focus());lastTick=performance.now();roundTime=0;timer=setInterval(()=>{
 const now=performance.now(),dt=Math.min(now-lastTick,250);lastTick=now;if(document.hidden)return
 elapsed.value+=dt
 if(challenge.value?.kind==='catch'){
 roundTime+=dt;progress.value=Math.min(1,roundTime/ROUND_MS)
 if(roundTime>=ROUND_MS){moves.value.push(lane.value);round.value++;roundTime=0;progress.value=0;if(done.value){clearInterval(timer);void finish()}}
 }else if(elapsed.value>=90000){clearInterval(timer);void finish()}
 },50)}
function selectLane(n:number){if(phase.value==='playing')lane.value=n}
function key(e:KeyboardEvent){if(challenge.value?.kind!=='catch'||phase.value!=='playing')return;if(['ArrowLeft','ArrowRight','1','2','3'].includes(e.key)){e.preventDefault();lane.value=e.key==='ArrowLeft'?Math.max(0,lane.value-1):e.key==='ArrowRight'?Math.min(2,lane.value+1):Number(e.key)-1}}
function flip(i:number){if(locked.value||phase.value!=='playing'||matched.value.includes(i)||flipped.value.includes(i))return
 flipped.value.push(i)
 if(flipped.value.length===2){locked.value=true;const [a,b]=flipped.value as [number,number];moves.value.push(a,b);matched.value=memoryStep(challenge.value!.board,matched.value,a,b)
 flipTimer=setTimeout(()=>{flipped.value=[];locked.value=false;if(done.value){clearInterval(timer);void finish()}},650)}
}
async function finish(){if(busy.value||!challenge.value)return;clearInterval(timer);clearTimeout(flipTimer);phase.value='result';busy.value=true;error.value=''
 try{const {data,error:e}=await db.rpc('wedding_arcade_finish',{run_id:challenge.value.id,actions:moves.value});fail(e);if(!alive)return;result.value=data;emit('updated')}
 catch(e){error.value=friendly(e)}finally{busy.value=false}}
function menu(){clearInterval(timer);clearTimeout(flipTimer);phase.value='menu';challenge.value=null;locked.value=false;error.value=''}
onUnmounted(()=>{alive=false;clearInterval(timer);clearTimeout(flipTimer)})
</script>
<template><section class="pet-arcade" aria-label="Minijuegos del perrito">
 <template v-if="phase==='menu'"><div class="arcade-heading"><Gamepad2 :size="23"/><div><h4>Una tarde de juegos</h4><p>Divertíos juntos y ganad monedas y experiencia.</p></div></div>
 <button class="arcade-card" :disabled="disabled||busy" @click="start('catch')"><span class="arcade-cover catch-cover">🦴<span>🐾</span>🎾</span><span><b>Atrapa los premios</b><small>Mueve al perrito y recoge 12 premios.<br/>Hasta 24 monedas · 36 XP</small></span><span>Jugar →</span></button>
 <button class="arcade-card" :disabled="disabled||busy" @click="start('memory')"><span class="arcade-cover memory-cover">🐾<span>?</span>🐾</span><span><b>Parejas perrunas</b><small>Encuentra sus seis parejas favoritas.<br/>Hasta 24 monedas · 36 XP</small></span><span>Jugar →</span></button>
 <p class="arcade-note">Cada partida usa 8 de energía y 5 de barriguita. Hasta 12 partidas por hora. Las monedas son solo del juego.</p><p v-if="disabled" class="arcade-note">Despierta a tu compi y espera a que termine de cargar para jugar.</p></template>
 <template v-else><header class="arcade-game-header"><button v-if="phase!=='result'" class="pet-icon-button" @click="menu" aria-label="Abandonar partida"><ArrowLeft :size="18"/></button><b>{{challenge?.kind==='catch'?'Atrapa los premios':'Parejas perrunas'}}</b><span>{{score}} / {{challenge?.kind==='catch'?12:6}}</span></header>
 <div v-if="phase==='ready'" class="arcade-ready"><VirtualDog/><h4>¿Listos para jugar?</h4><p>{{challenge?.kind==='catch'?'Elige uno de los tres caminos antes de que el premio llegue al suelo. Usa los botones o las flechas del teclado.':'Destapa dos cartas y encuentra las parejas. Tienes 90 segundos y 24 intentos.'}}</p><button class="btn olive" @click="begin">¡Vamos!</button><small>Salir o cambiar de habitación abandona la partida.</small></div>
 <div v-else-if="phase==='playing'" class="arcade-board" ref="boardElement" tabindex="0" @keydown="key" :aria-label="challenge?.kind==='catch'?'Zona de juego. Flechas izquierda y derecha para mover al perrito.':'Tablero de parejas. Destapa dos cartas.'">
 <template v-if="challenge?.kind==='catch'"><div class="arcade-progress"><span :style="{width:round/CATCH_ROUNDS*100+'%'}"></span></div><p class="arcade-round">Premio {{round+1}} de 12 · Elige un camino</p><div class="catch-field"><i v-for="n in 3" :key="n" :style="{left:(n-1)*33.333+'%'}"></i><span class="falling-treat" :style="{left:(challenge.board[round]!*33.333+16.666)+'%',top:(10+progress*58)+'%'}">{{round%2?'🎾':'🦴'}}</span><div class="catch-dog" :style="{left:(lane*33.333+16.666)+'%'}"><VirtualDog/></div></div><div class="catch-controls"><button v-for="n in 3" :key="n" :aria-pressed="lane===n-1" @click="selectLane(n-1)">{{['← Izquierda','● Centro','Derecha →'][n-1]}}</button></div></template>
 <template v-else><p class="arcade-round">{{Math.ceil((90000-elapsed)/1000)}} s · {{24-moves.length/2}} intentos</p><div class="memory-grid"><button v-for="(symbol,i) in challenge?.board" :key="i" :class="{revealed:flipped.includes(i)||matched.includes(i),matched:matched.includes(i)}" :disabled="locked||matched.includes(i)" :aria-label="'Carta '+(i+1)+(matched.includes(i)?', encontrada':flipped.includes(i)?', '+MEMORY_ICONS[symbol]:', oculta')" @click="flip(i)">{{flipped.includes(i)||matched.includes(i)?MEMORY_ICONS[symbol]:'🐾'}}</button></div></template>
 </div>
 <div v-else class="arcade-result" role="status"><VirtualDog mood="petting"/><h4>{{busy?'Guardando vuestra aventura…':result?'¡Qué bien lo habéis pasado!':'No se ha podido guardar'}}</h4><template v-if="result"><p>{{result.score}} {{challenge?.kind==='catch'?'premios atrapados':'parejas encontradas'}}</p><div class="arcade-prizes"><span><Coins/> +{{result.coins}}</span><span><Sparkles/> +{{result.xp}} XP</span></div><small>Recompensas guardadas en tu cuenta</small><button class="btn olive" @click="menu">Volver a los juegos</button></template><template v-else-if="!busy"><button class="btn olive" @click="finish">Reintentar guardado</button><button class="text-link" @click="menu">Volver a los juegos</button></template></div>
 </template><p v-if="error" class="pet-error" role="alert">{{error}}</p>
</section></template>
