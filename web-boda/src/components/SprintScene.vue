<script setup lang="ts">
import {computed,onMounted,onUnmounted,ref} from 'vue'
import type {Sprint} from '../lib/sprint'
const props=defineProps<{state:Sprint;running:boolean;accessory?:string}>()
const svg=ref<SVGSVGElement|null>(null),height=ref(400)
let observer:ResizeObserver
const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches
const ground=computed(()=>height.value*.78),night=computed(()=>props.state.tick>=1800)
const stride=computed(()=>props.running&&props.state.y===0&&!reduced?Math.sin(props.state.tick*.55)*11:0)
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
 <g :transform="`translate(110 ${ground-state.y/10})`">
  <g fill="#744a34" stroke="#68432e" stroke-width="2"><rect x="-22" :y="-22+stride/2" width="12" :height="22-stride/2" rx="5"/><rect x="12" :y="-22-stride/2" width="12" :height="22+stride/2" rx="5"/></g>
  <path d="M-25 -31 Q-44 -32 -38 -48 Q-31 -54 -31 -43" fill="none" stroke="#ab7950" stroke-width="11" stroke-linecap="round"/>
  <ellipse cx="-1" cy="-32" rx="29" ry="21" fill="#a27148"/>
  <circle cx="20" cy="-53" r="21" fill="#b58256"/><ellipse cx="35" cy="-46" rx="16" ry="11" fill="#c69a6b"/>
  <g fill="#c08d5c"><circle v-for="n in 16" :key="n" :cx="-23+(n*13)%46" :cy="-43+(n*7)%22" r="5"/><circle cx="11" cy="-69" r="6"/><circle cx="21" cy="-73" r="6"/><circle cx="30" cy="-68" r="6"/></g>
  <ellipse cx="8" cy="-51" rx="10" ry="18" fill="#795036"/><circle cx="32" cy="-57" r="3" fill="#302b25"/><circle cx="33" cy="-58" r="1" fill="#fff"/><ellipse cx="47" cy="-48" rx="4" ry="3" fill="#352c28"/><path d="M34 -39 Q39 -34 43 -40" fill="none" stroke="#805139" stroke-width="2"/>
  <path v-if="accessory==='bandana'" d="M9 -33 L30 -38 L23 -19Z" fill="#d8816a"/>
  <path v-if="accessory==='collar'" d="M9 -33 L29 -37" stroke="#6c9a81" stroke-width="5"/>
  <path v-if="accessory==='bow'" d="M14 -34 L5 -42 L5 -25 L14 -34 L24 -41 L24 -25Z" fill="#a28ab7"/>
  <g v-if="accessory==='hat'" fill="#d4b077" stroke="#95724d" stroke-width="2"><path d="M5 -72 L9 -88 H31 L35 -72Z"/><path d="M0 -72 H41" stroke-width="5"/></g>
 </g>
 <text x="28" :y="height-18" class="sprint-landmark">{{night?'BAJO LAS ESTRELLAS':'UN PASEO CONTIGO'}} · L &amp; J</text>
</svg></template>
