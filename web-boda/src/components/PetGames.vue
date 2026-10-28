<script setup lang="ts">
import {ref} from 'vue'
import FlappyGame from './FlappyGame.vue'
import RunnerGame from './RunnerGame.vue'
import SprintGame from './SprintGame.vue'
defineProps<{disabled?:boolean;accessory?:string}>()
const emit=defineEmits<{updated:[];active:[value:boolean]}>(),active=ref('')
function change(game:string,value:boolean){active.value=value?game:'';emit('active',value)}
</script>
<template><div class="pet-games"><FlappyGame v-show="!active||active==='flappy'" :disabled="disabled||!!active&&active!=='flappy'" :accessory="accessory" @active="change('flappy',$event)" @updated="emit('updated')"/><RunnerGame v-show="!active||active==='runner'" :disabled="disabled||!!active&&active!=='runner'" :accessory="accessory" @active="change('runner',$event)" @updated="emit('updated')"/><SprintGame v-show="!active||active==='sprint'" :disabled="disabled||!!active&&active!=='sprint'" :accessory="accessory" @active="change('sprint',$event)" @updated="emit('updated')"/></div></template>
