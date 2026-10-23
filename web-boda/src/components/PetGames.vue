<script setup lang="ts">
import {ref} from 'vue'
import FlappyGame from './FlappyGame.vue'
import RunnerGame from './RunnerGame.vue'
defineProps<{disabled?:boolean;accessory?:string}>()
const emit=defineEmits<{updated:[];active:[value:boolean]}>(),active=ref('')
function change(game:string,value:boolean){active.value=value?game:'';emit('active',value)}
</script>
<template><div class="pet-games"><FlappyGame v-show="active!=='runner'" :disabled="disabled" :accessory="accessory" @active="change('flappy',$event)" @updated="emit('updated')"/><RunnerGame v-show="active!=='flappy'" :disabled="disabled" :accessory="accessory" @active="change('runner',$event)" @updated="emit('updated')"/></div></template>
