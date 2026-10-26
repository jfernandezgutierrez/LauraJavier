<script setup lang="ts">
import {nextTick,onMounted,onUnmounted,ref,watch} from 'vue'
import {Maximize2,Minimize2} from 'lucide-vue-next'
const expanded=ref(false),native=ref(false),stage=ref<HTMLElement|null>(null)
let oldBody='',oldHtml='',locked=false,previous:HTMLElement|null=null
function measure(){stage.value?.style.setProperty('--game-height',`${document.fullscreenElement?innerHeight:(visualViewport?.height??innerHeight)}px`)}
function restore(){if(!locked)return;document.body.style.overflow=oldBody;document.documentElement.style.overflow=oldHtml;locked=false}
watch(expanded,async value=>{
 if(value){previous=document.activeElement as HTMLElement;oldBody=document.body.style.overflow;oldHtml=document.documentElement.style.overflow;locked=true;document.body.style.overflow='hidden';document.documentElement.style.overflow='hidden'}
 else{restore();await nextTick();previous?.focus({preventScroll:true})}
 await nextTick();measure();window.dispatchEvent(new Event('huellas-viewport-change'))
})
async function toggle(){
 if(expanded.value){if(document.fullscreenElement===stage.value)await document.exitFullscreen().catch(()=>{});expanded.value=false;return}
 expanded.value=true;await nextTick();measure()
 if(document.fullscreenEnabled&&stage.value?.requestFullscreen){try{await stage.value.requestFullscreen();native.value=true}catch{/* The fitted viewport works without native fullscreen. */}}
}
function changed(){const isNative=document.fullscreenElement===stage.value;if(native.value&&!isNative)expanded.value=false;native.value=isNative;measure();window.dispatchEvent(new Event('huellas-viewport-change'))}
function key(e:KeyboardEvent){
 if(!expanded.value)return
 if(e.key==='Escape'&&!native.value&&!stage.value?.querySelector('.playing-flight'))expanded.value=false
 if(e.key==='Tab'){
  const controls=[...stage.value!.querySelectorAll<HTMLElement>('button,a[href],input,select,textarea,[tabindex]')].filter(el=>el.tabIndex>=0&&!el.matches(':disabled')&&el.getClientRects().length)
  const first=controls[0],last=controls.at(-1)
  if(e.shiftKey&&(document.activeElement===first||!stage.value?.contains(document.activeElement))){e.preventDefault();last?.focus()}
  else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first?.focus()}
 }
}
function resized(){measure();window.dispatchEvent(new Event('huellas-viewport-change'))}
onMounted(()=>{measure();window.addEventListener('resize',resized);visualViewport?.addEventListener('resize',measure);document.addEventListener('fullscreenchange',changed);window.addEventListener('keydown',key)})
onUnmounted(()=>{restore();window.removeEventListener('resize',resized);visualViewport?.removeEventListener('resize',measure);document.removeEventListener('fullscreenchange',changed);window.removeEventListener('keydown',key);if(document.fullscreenElement===stage.value)void document.exitFullscreen().catch(()=>{})})
</script>
<template><Teleport to="body" :disabled="!expanded"><section ref="stage" class="game-viewport" :class="{'is-expanded':expanded}"><div class="viewport-bar"><span v-if="expanded">{{native?'Pantalla completa':'Ajustado a tu pantalla'}}</span><button @click="toggle" :aria-pressed="expanded" :aria-label="expanded?'Salir de pantalla completa':'Pantalla completa'"><Minimize2 v-if="expanded" :size="17"/><Maximize2 v-else :size="17"/><span>{{expanded?'Reducir':'Pantalla completa'}}</span></button></div><div class="viewport-content"><slot/></div></section></Teleport></template>
