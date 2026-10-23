<script setup lang="ts">
import { ref,onMounted,onUnmounted } from 'vue'
import { X, ArrowRight } from 'lucide-vue-next'
import { db,fail,friendly } from '../lib/supabase'
import {refreshProfile,user} from '../lib/session'
const props=defineProps<{recovery?:boolean}>(),emit=defineEmits<{close:[]}>()
const mode=ref(props.recovery?'update':'login'),email=ref(''),password=ref(''),busy=ref(false),message=ref(''),error=ref(''),dialog=ref<HTMLDialogElement>()
onMounted(()=>dialog.value?.showModal());onUnmounted(()=>dialog.value?.close())
async function submit(){busy.value=true;message.value='';error.value='';try{
 if(mode.value==='login'){const {data,error:e}=await db.auth.signInWithPassword({email:email.value,password:password.value});fail(e);user.value=data.user;await refreshProfile();emit('close')}
 else if(mode.value==='reset'){const {error:e}=await db.auth.resetPasswordForEmail(email.value,{redirectTo:location.origin+'/'});fail(e);message.value='Si existe una cuenta, recibirás un enlace para cambiar la contraseña.'}
 else {const {error:e}=await db.auth.updateUser({password:password.value});fail(e);message.value='Contraseña actualizada. Ya puedes continuar.'}
}catch(e){error.value=friendly(e)}finally{busy.value=false}}
</script>
<template><dialog ref="dialog" class="auth-modal" @cancel.prevent="emit('close')"><button class="close" aria-label="Cerrar" @click="emit('close')"><X/></button><p class="eyebrow">UN SITIO PARA LOS NUESTROS</p><h2>{{mode==='reset'?'Recupera tu acceso':mode==='update'?'Tu nueva contraseña':'Qué alegría verte'}}</h2><p>Tu invitación, tus canciones y las aventuras de nuestro perrito.</p><p v-if="mode==='login'" class="notice">Las cuentas se crean desde la invitación personal que te envían Laura y Javier. Si todavía no la tienes, pídeles tu enlace.</p><form @submit.prevent="submit"><label v-if="mode!=='update'">Correo electrónico<input v-model="email" type="email" required autocomplete="email"/></label><label v-if="mode!=='reset'">Contraseña<input v-model="password" type="password" required :minlength="mode==='login'?1:10" :autocomplete="mode==='login'?'current-password':'new-password'"/><small v-if="mode!=='login'">Al menos 10 caracteres.</small></label><p v-if="error" class="error" role="alert">{{error}}</p><p v-if="message" class="success" role="status">{{message}}</p><button class="btn full" :disabled="busy">{{busy?'Un momento…':mode==='reset'?'Enviar enlace':mode==='update'?'Guardar contraseña':'Entrar'}}<ArrowRight :size="17"/></button></form><button v-if="mode==='login'" class="text-link" @click="mode='reset'">He olvidado mi contraseña</button><button v-if="mode==='reset'" class="text-link" @click="mode='login'">Volver a entrar</button><p class="small muted">Tu nombre y datos de contacto no se muestran en la clasificación. Solo aparecerá tu alias si tú lo decides.</p></dialog></template>
