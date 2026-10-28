<script setup lang="ts">
import {computed,ref} from 'vue'
import {appBase} from '../lib/urls'
const props=withDefaults(defineProps<{view?:'side'|'back';pose?:'run'|'jump'|'duck';tick?:number;accessory?:string}>(),{view:'side',pose:'run',tick:0,accessory:''})
const fallback=ref(false),reduced=matchMedia('(prefers-reduced-motion: reduce)').matches
const col=computed(()=>fallback.value?3:props.pose==='jump'?2:props.pose==='duck'?3:reduced?0:Math.floor(props.tick/8)%2)
const row=computed(()=>fallback.value?1:props.view==='back'?1:0)
const neck=computed(()=>props.view==='back'?{x:50,y:props.pose==='duck'?68:49}:{x:76,y:props.pose==='duck'?72:props.pose==='jump'?53:61})
</script>
<template><svg class="game-dog-sprite" viewBox="0 0 100 100" aria-hidden="true">
 <svg width="100" height="100" :viewBox="`${col*100} ${row*100} 100 100`" overflow="hidden"><image :href="appBase+'images/'+(fallback?'dog-sprites.png':'dog-game-sprites.png')" width="400" height="200" preserveAspectRatio="none" @error="fallback=true"/></svg>
 <g v-if="accessory" :transform="`translate(${neck.x} ${neck.y})`">
  <path v-if="accessory==='bandana'" d="M-12 -3 Q0 2 12 -3 L3 13 L-3 2Z" fill="#bd705f" stroke="#8d4f42" stroke-width="1"/>
  <g v-if="accessory==='collar'"><path d="M-11 -2 Q0 3 11 -2" fill="none" stroke="#728b62" stroke-width="3.5"/><circle cx="2" cy="3" r="2.5" fill="#e6b95d"/></g>
  <g v-if="accessory==='bow'" fill="#a88ab9" stroke="#6a527a" stroke-width="1"><path d="M-1 0 L-10 -6 V6Z M1 0 L10 -6 V6Z"/><circle r="2.7"/></g>
 </g>
 <g v-if="accessory==='hat'" :transform="view==='back'?`translate(50 ${pose==='duck'?57:12})`:`translate(73 ${pose==='duck'?49:pose==='jump'?8:17})`" fill="#cca978" stroke="#927248" stroke-width="1.5"><path d="M-12 0 L-9 -10 Q0 -13 9 -10 L12 0Z"/><path d="M-17 0 Q0 5 17 0" fill="none" stroke-width="3"/></g>
</svg></template>
<style scoped>.game-dog-sprite{display:block;width:100%;height:100%;overflow:visible;pointer-events:none;opacity:1;mix-blend-mode:normal;isolation:isolate}</style>
