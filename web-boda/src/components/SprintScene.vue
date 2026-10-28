<script setup lang="ts">
import {computed,onMounted,onUnmounted,ref} from 'vue'
import GameDog from './GameDog.vue'
import type {Sprint} from '../lib/sprint'
const props=defineProps<{state:Sprint;running:boolean;accessory?:string}>()
const svg=ref<SVGSVGElement|null>(null),height=ref(400)
let observer:ResizeObserver
const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches
const ground=computed(()=>height.value*.78),night=computed(()=>props.state.tick>=1800)
const drift=computed(()=>reduced?0:props.state.distance/10)
onMounted(()=>{observer=new ResizeObserver(entries=>{const r=entries[0]?.contentRect;if(r?.width)height.value=600*r.height/r.width});if(svg.value)observer.observe(svg.value)})
onUnmounted(()=>observer?.disconnect())
</script>
<template><svg ref="svg" class="sprint-scene" :class="{night}" :viewBox="`0 0 600 ${height}`" aria-hidden="true">
 <rect width="600" :height="height" class="sprint-sky"/>
 <g v-if="night" fill="#fff3d5"><circle v-for="n in 16" :key="n" :cx="(n*137)%600" :cy="24+(n*43)%(ground*.6)" :r="n%3===0?2:1"/></g>
 <circle cx="490" :cy="ground*.27" r="29" :fill="night?'#fff2cf':'#e7b768'"/>
 <circle v-if="night" cx="502" :cy="ground*.27-10" r="27" fill="#253c53"/>
 <g v-for="n in 4" :key="n" :transform="`translate(${((n*185-drift*.06)%780+780)%780-100} ${ground*.2+n%2*35})`" class="sprint-cloud"><path d="M0 20 Q-7 5 10 4 Q18 -15 36 0 Q56 -8 60 13 Q80 10 80 23 H0Z"/></g>
 <path :d="`M0 ${ground-50} Q80 ${ground-130} 170 ${ground-55} T350 ${ground-80} T600 ${ground-60} V${height} H0Z`" class="sprint-hills"/>
 <g v-for="n in 7" :key="n" :transform="`translate(${((n*120-drift*.2)%840+840)%840-90} ${ground-12})`" class="sprint-trees"><path d="M0 0 V-65 M-26 -29 L0 -84 L27 -29Z" stroke-width="5" stroke-linejoin="round"/></g>
 <path :d="`M0 ${ground} H600 V${height} H0Z`" class="sprint-earth"/>
 <path :d="`M0 ${ground} H600`" stroke="#8a8f60" stroke-width="3"/>
 <g stroke="#b8af8d" stroke-linecap="round"><path v-for="n in 18" :key="n" :d="`M${((n*51-drift)%700+700)%700-40} ${ground+12+n%3*14} h${n%2?10:4}`" stroke-width="2"/></g>
 <g v-for="o in state.obstacles" :key="o.id" :transform="`translate(${o.x/10} ${ground})`">
  <ellipse :cx="o.width/20" cy="2" :rx="o.width/16" ry="5" fill="#354b3430"/>
  <g v-if="o.kind!==1"><rect y="-45" :width="o.width/10" height="45" rx="10" fill="#987154" stroke="#6e513b" stroke-width="2"/><path :d="`M7 -34 H${o.width/10-8} M9 -21 H${o.width/10-6} M10 -9 H${o.width/10-12}`" stroke="#bd9870" stroke-width="3" stroke-linecap="round"/><ellipse :cx="o.width/10-8" cy="-23" rx="7" ry="18" fill="#d1b181"/><ellipse :cx="o.width/10-8" cy="-23" rx="3" ry="10" fill="none" stroke="#a97d50"/></g>
  <g v-else><path d="M0 0 L1 -35 L12 -61 L26 -65 L37 -31 L38 0Z" fill="#818b87" stroke="#606e69" stroke-width="2"/><path d="M12 -60 L18 -30 L3 -16 M18 -30 L35 -22 M18 -30 L26 -63" fill="none" stroke="#a6b2a7" stroke-width="3"/></g>
 </g>
 <ellipse cx="112" :cy="ground+3" :rx="Math.max(12,30-state.y/80)" ry="6" fill="#4f65452b"/>
 <svg x="71" :y="ground-state.y/10-77" width="82" height="82" overflow="visible"><GameDog view="side" :pose="state.y>0?'jump':'run'" :tick="state.tick" :accessory="accessory"/></svg>
 <text x="28" :y="height-18" class="sprint-landmark">{{night?'BAJO LAS ESTRELLAS':'UN PASEO CONTIGO'}} · L &amp; J</text>
</svg></template>
