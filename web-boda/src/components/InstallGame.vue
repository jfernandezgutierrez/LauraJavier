<script setup lang="ts">
import {ref} from 'vue'
import {Download,Smartphone,X} from 'lucide-vue-next'
import {installed,installPrompt,install} from '../lib/install'
const help=ref(false)
async function open(){if(installPrompt.value)await install();else help.value=!help.value}
</script>
<template><div class="install-game" v-if="!installed"><button @click="open"><Download :size="16"/> Instalar el juego en mi móvil</button><div v-if="help" class="install-help"><button @click="help=false" aria-label="Cerrar instrucciones"><X :size="18"/></button><Smartphone :size="25"/><b>Tu perrito, a un toque</b><p><strong>iPhone:</strong> abre esta web en Safari, pulsa Compartir y «Añadir a pantalla de inicio».</p><p><strong>Android:</strong> abre esta web en Chrome, pulsa el menú ⋮ y «Instalar aplicación» o «Añadir a pantalla de inicio».</p><p>Se abrirá directamente en el juego. Necesitas conexión y tu cuenta para jugar y guardar el progreso.</p></div></div></template>
<style scoped>
.install-game{padding:8px 14px 14px;text-align:center;font-size:12px}.install-game>button{border:1px solid #c8d0b7;border-radius:13px;background:#edf1e4;color:#536344;min-height:44px;padding:9px 16px;display:inline-flex;align-items:center;gap:8px}.install-help{position:relative;text-align:left;border-radius:16px;background:#f3efe5;padding:18px;margin-top:10px}.install-help>button{position:absolute;right:5px;top:5px;background:none;border:0;padding:10px}.install-help>b{display:block;margin:6px 0}.install-help p{font-size:12px;line-height:1.7;margin:10px 0}
</style>
