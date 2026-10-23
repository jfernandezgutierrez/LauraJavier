<script setup lang="ts">
import {computed,ref,onMounted,onUnmounted} from 'vue'
const props=defineProps<{date?:string;couple?:string}>(),now=ref(Date.now());let timer:ReturnType<typeof setInterval>
const remaining=computed(()=>{const end=Date.parse(props.date||'');return Number.isFinite(end)?Math.max(0,Math.floor((end-now.value)/1000)):null})
const parts=computed(()=>{const s=remaining.value||0;return [{n:Math.floor(s/86400),t:'días'},{n:Math.floor(s%86400/3600),t:'h'},{n:Math.floor(s%3600/60),t:'min'}]})
onMounted(()=>timer=setInterval(()=>now.value=Date.now(),1000));onUnmounted(()=>clearInterval(timer))
</script>
<template><div class="wedding-clock"><span>♡ {{couple||'Laura y Javier'}}</span><b v-if="remaining===null">Nuestro gran día está por llegar</b><b v-else-if="remaining===0">¡Que viva el amor!</b><div v-else><span v-for="p in parts" :key="p.t"><strong>{{String(p.n).padStart(2,'0')}}</strong><small>{{p.t}}</small></span></div><small v-if="remaining!==null&&remaining>0">para el «sí, quiero»</small></div></template>
<style scoped>
.wedding-clock{position:absolute;top:56px;right:12px;z-index:2;max-width:46%;padding:10px 12px;background:#fffaf0f0;border:3px solid #d5b993;border-radius:12px;box-shadow:0 4px 0 #7f6d4b20;text-align:center;color:#715b46;transform:rotate(2deg)}.wedding-clock>span{display:block;font:italic 12px Georgia,serif}.wedding-clock>div{display:flex;justify-content:center;gap:9px;margin:5px 0}.wedding-clock strong{font-size:17px;display:block}.wedding-clock small{font-size:8px;display:block}.wedding-clock b{display:block;font-size:10px;max-width:130px;margin-top:6px}
</style>
